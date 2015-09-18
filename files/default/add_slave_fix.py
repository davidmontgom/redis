
import os
import zc.zk
import logging 
logging.basicConfig()
import paramiko
from redis.sentinel import Sentinel
import redis
import time
zk_host_list = '1.zk.do.development.ny.forexhui.com'.split(',')
for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
zk = zc.zk.ZooKeeper(zk_host_str) 

# node = 'do-sentinal-ny-development'
# path = '/%s/' % (node)
# if zk.exists(path):
#     addresses = zk.children(path)
#     sentinal_servers = list(set(addresses))
#     for ip_address in sentinal_servers:
#         os.system("sudo ufw allow from %s to any port 26379" % ip_address)
#         os.system("sudo ufw allow from %s to any port 16379" % ip_address)
#         os.system("sudo ufw allow from %s to any port 6379" % ip_address)
#         
# exit()
#shard = open('/var/shard.txt').readlines()[0].strip()

sudo ufw allow from 162.243.54.81 to any port 6379

shard = 'shard1'
node = 'do-redis-ny-development-%s' % (shard)
path = '/%s/' % (node)
master_ipaddress = None
print path
this_ip = '192.241.190.118'
#this_ip = '#{node[:ipaddress]}'
if zk.exists(path):
    addresses = zk.children(path)
    redis_hosts = list(addresses)
    print redis_hosts
    for ip in redis_hosts:
        print 'ip',ip
        if ip != this_ip:
            r = redis.StrictRedis(host=ip,port=6379)
            info = r.info()
            print 'role:',info['role']
            if info['role']=='master':
                master_ipaddress = ip
                break
print 'master_ipaddress:',master_ipaddress

if master_ipaddress and len(redis_hosts)>1:
    r = redis.StrictRedis(host=this_ip,port=6379)
    r.slaveof(host=master_ipaddress, port=6379)
    print 'Syncing....'
    syncing = True
    while syncing == True:
        info = r.info()
        print 'master_sync_in_progress:',info['master_sync_in_progress'], 'master_link_status:',info['master_link_status']
        if info['master_link_status']=='up':
            syncing = False
        time.sleep(3)
    print 'slave is connected'
