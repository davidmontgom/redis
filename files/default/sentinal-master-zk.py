"""
1) Find all masters
2) Format sentinal.conf in /var incase sentinal restarts
3) Need to create a checksum
4) Rstart supervisr 
"""
import time
import sys
import os
import hashlib

import zc.zk
import logging #https://kazoo.readthedocs.org/en/latest/basic_usage.html
logging.basicConfig()


running_in_pydev = 'PYDEV_CONSOLE_ENCODING' in os.environ

SETTINGS_FILE='/etc/ec2/meta_data.yaml'
from yaml import load, dump
from yaml import Loader, Dumper
f = open(SETTINGS_FILE)
meta_parms = load(f, Loader=Loader)
f.close()

sys.path.append(meta_parms['class_path'])
import utilities as util
import ec2Utilities as ec2u
import cloudUtilities as cu
try:
    import doUtilities as dou
except:
    pass
import redis
parms = util.getParms() 

environment = parms['environment']
location = parms['location']
datacenter = parms['datacenter']


def create_sentinal_config(shard_master_hash):
    
    conf = ''
    for shard,master in shard_master_hash.iteritems():
        temp = """
sentinel monitor shard%s %s 6379 1
sentinel down-after-milliseconds shard%s 60000
sentinel failover-timeout shard%s 180000
sentinel parallel-syncs shard%s 1
        """ % (shard,master,shard,shard,shard)
        conf = conf + temp
    return conf

def find_master():
    """
    Get master from r53 by shard.  Not valid redis server unless in r53
    This will be used to create the config file for sentinal servers
    """
    
    domain = parms[datacenter][environment][location]['redis']['domain']
    shard_identifier = parms[datacenter][environment][location]['redis']['shard_identifier']
    shard_count = parms[datacenter][environment][location]['redis']['shard_count']
    requried_count = parms[datacenter][environment][location]['redis']['requried_count']
    public_domain = parms[datacenter][environment][location]['redis']['public_domain']
    domain = domain.split('.')
    if running_in_pydev ==True  and public_domain:
        public_domain = '%s-public.%s.%s' % (domain[0],domain[1],domain[2])  

    domain = '%s.%s.%s' % (domain[0],domain[1],domain[2]) 

    existing_domains = ec2u.getExistingSubdomains(aws_access_key_id,aws_secret_access_key,route53_zone_id)
    shard_hash = {}
    shard_hash_public={}
    for shard in xrange(shard_count):
        temp = {}
        for count in xrange(requried_count):
            t = "%s-%s%s-%s" % (count+1,shard_identifier,shard+1,domain)
            if existing_domains.has_key(t+'.'):
                temp[t]=existing_domains[t+'.'][0]
        if temp:
            shard_hash[shard+1]=temp
        
        #This is only because of aws and running local
        if running_in_pydev==True and public_domain:
            temp = {}
            for count in xrange(requried_count):
                t = "%s-%s%s-%s" % (count+1,shard_identifier,shard+1,public_domain)
                if existing_domains.has_key(t+'.'):
                    temp[t]=existing_domains[t+'.'][0]
            if temp:
                shard_hash_public[shard+1]=temp

    shard_master = {}
    if running_in_pydev==True and public_domain:
        for shard,domains in shard_hash_public.iteritems():
            master=None
            for domain,ipaddress in domains.iteritems():
                try:
                    r = redis.StrictRedis(host=ipaddress,port=6379)
                    role = r.info()
                    #pprint(role)
                    if role['role']=='master':
                        ipaddress = shard_hash[shard][domain.replace('-public','').strip()]
                        shard_master[shard]=ipaddress
                except:
                    print 'master error'
    else:
        for shard,domains in shard_hash.iteritems():
            master=None
            for domain,ipaddress in domains.iteritems():
                r = redis.StrictRedis(host=ipaddress,port=6379)
                role = r.info()
                #pprint(role)
                if role['role']=='master':
                    shard_master[shard]=ipaddress
    #always return private
    return shard_master
    

while True:
    
    
    shard_identifier = parms[datacenter][environment][location]['redis']['shard_identifier']
    shard_count = parms[datacenter][environment][location]['redis']['shard_count']
    
    shard_master = {}
    zk_host_list = open('/var/zookeeper_hosts.json').readlines()[0]
    #zk_host_list = '1.zk.sp.development.central.govspring.com'
    zk_host_list = zk_host_list.split(',')
    for i in xrange(len(zk_host_list)):
        zk_host_list[i]=zk_host_list[i]+':2181' 
    zk_host_str = ','.join(zk_host_list)
    zk = zc.zk.ZooKeeper(zk_host_str)
    
    for sc in xrange(shard_count):
        node = 'redis-%s-%s-%s' % (datacenter,environment,location)
        path = '/%s-%s%s/' % (node,shard_identifier,sc+1)
    
        data = ''
        addresses = zk.children(path)
        if zk.exists(path):
            ip_address_list = list(sorted(addresses))
            for ip_address in ip_address_list:
                r = redis.StrictRedis(host=ip_address,port=6379)
                role = r.info()
                if role['role']=='master':
                    shard_master[sc+1]=ip_address
    shard_master_hash = shard_master


    if running_in_pydev==True:
        sentinal_conf_file = '/tmp/sentinal.conf'
        checksum_path = '/tmp/sentinal.checksum'
    else:
        sentinal_conf_file = '/var/sentinal.conf'
        checksum_path = '/var/sentinal.checksum'
        
    if not os.path.exists(sentinal_conf_file):
        checksum_changed=True
        old_checksum = False
    else:
        fnl=["sentinal_conf_file"]
        old_checksum = [(fname, hashlib.md5(open(sentinal_conf_file, 'rb').read()).hexdigest()) for fname in fnl][0][1]
        checksum_changed=False
        
    #shard_master_hash = find_master()
    sentinal_conf = create_sentinal_config(shard_master_hash)
    
    new_checksum = hashlib.md5(sentinal_conf).hexdigest()

    if new_checksum != old_checksum:
        checksum_changed==True
        old_checksum = new_checksum
        print 'different'
    else:
        print 'same'

    if checksum_changed==True:
        f = open(sentinal_conf_file,'w')
        f.write(sentinal_conf)
        f.close()
        #os.system('/usr/local/bin/supervisorctl restart all')
    print 'waiting'
    time.sleep(20)
   