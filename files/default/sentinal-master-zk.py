"""
1) Find all masters
2) Format sentinal.conf in /var incase sentinal restarts
3) Need to create a checksum
4) Restart supervisr 
"""
import time
import sys
import os
import hashlib
import zc.zk
import redis
import logging #https://kazoo.readthedocs.org/en/latest/basic_usage.html
logging.basicConfig()
running_in_pydev = 'PYDEV_CONSOLE_ENCODING' in os.environ
SETTINGS_FILE='/root/.bootops.yaml'
from yaml import load, dump
from yaml import Loader, Dumper
f = open(SETTINGS_FILE)
meta_parms = load(f, Loader=Loader)
f.close()
environment = meta_parms['environment']
location = meta_parms['location']
datacenter = meta_parms['datacenter']
slug = meta_parms['slug']
cluster_slug = open('/var/cluster_slug.txt').readlines()[0].strip()


if cluster_slug=='nocluster':
    findme = "%s-%s-%s-%s-%s" % ('redis',slug,datacenter,environment,location)
else:
    findme = "%s-%s-%s-%s-%s-%s" % ('redis',slug,datacenter,environment,location,cluster_slug)
    

#if datacenter!='local':
zk_host_list = open('/var/zookeeper_hosts.json').readlines()[0]
zk_host_list = zk_host_list.split(',')
# else:
#     zk_host_list =['1.zk.do.development.ny.forexhui.com']

#zk_host_list = '1.zk.do.development.ny.forexhui.com'
for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
zk = zc.zk.ZooKeeper(zk_host_str)

#do-development-ny-redis-forex-shard1

def get_shard_ip_hash():
    this_tree = zk.export_tree()
    tree = this_tree.splitlines()
    
    #tree = [u'/do-mysql-ny-development', u'/do-redis-ny-development', u'/do-redis-ny-development-shard1', u'/do-sentinal-ny-development', u'/do-zookeeper-ny-development', u'']
    
    shard_list = []
    for t in tree:
        if t.find(findme)>=0 and t.find('shard')>=0:
            shard_list.append(str(t))     
    shard_ip_hash = {}
    for shard in shard_list:
        addresses = zk.children(shard)
        print list(addresses)
        shard_ip_hash[shard]=list(set(addresses))
    print shard_ip_hash
    return shard_ip_hash
    
def create_sentinal_config(shard_master_hash):
    

    conf = ''
    for shard,master in shard_master_hash.iteritems():
        temp = """
sentinel monitor %s %s 6379 1
sentinel down-after-milliseconds %s 60000
sentinel failover-timeout %s 180000
sentinel parallel-syncs %s 1
        """ % (shard,master,shard,shard,shard)
        conf = conf + temp
    
    return conf

while True:
    
    shard_ip_hash = get_shard_ip_hash()
    print 'shard_ip_hash:',shard_ip_hash
    
    shard_master = {}
    for shard, ip_address_list in shard_ip_hash.iteritems():
        for ip_address in ip_address_list:
            print 'ip_address:',ip_address
            r = redis.StrictRedis(host=ip_address,port=6379)
            role = r.info()
            if role['role']=='master':
                shard_name = shard.split('-')[-1]
                shard_master[shard_name]=ip_address
                master_ip_address = ip_address
                break
    shard_master_hash = shard_master
    
    print 'shard_master_hash:',shard_master_hash

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

    sentinal_conf = create_sentinal_config(shard_master_hash)
    new_checksum = hashlib.md5(sentinal_conf).hexdigest()

#     if new_checksum != old_checksum:
#         checksum_changed==True
#         old_checksum = new_checksum
#         print 'different'
#     else:
#         print 'same'
    #if checksum_changed==True:
    f = open(sentinal_conf_file,'w')
    f.write(sentinal_conf)
    f.close()
    #os.system('/usr/local/bin/supervisorctl restart all')
    print 'waiting'
    time.sleep(20)
   