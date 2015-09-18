datacenter = node.name.split('-')[0]
server_type = node.name.split('-')[1]
location = node.name.split('-')[2]
  
data_bag("my_data_bag")
zk = data_bag_item("my_data_bag", "zk")
zk_hosts = zk[node.chef_environment][datacenter][location]["zookeeper_hosts"]

db = data_bag_item("my_data_bag", "my")
keypair=db[node.chef_environment][location]["ssh"]["keypair"]
username=db[node.chef_environment][location]["ssh"]["username"]


easy_install_package "zc.zk" do
  action :install
end

easy_install_package "paramiko" do
  action :install
end

easy_install_package "redis" do
  action :upgrade
end


if datacenter!='local' and server_type=='redis'
  script "add_slave" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import os
import zc.zk
import logging 
logging.basicConfig()
import paramiko
from redis.sentinel import Sentinel
import redis
import time
zk_host_list = '#{zk_hosts}'.split(',')
for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
zk = zc.zk.ZooKeeper(zk_host_str) 
shard = open('/var/shard.txt').readlines()[0].strip()
node = '#{datacenter}-redis-#{location}-#{node.chef_environment}-%s' % (shard)
path = '/%s/' % (node)
master_ipaddress = None
this_ip = '#{node[:ipaddress]}'
if zk.exists(path):
    addresses = zk.children(path)
    redis_hosts = list(addresses)
    for ip in redis_hosts:
        if ip != this_ip:
          r = redis.StrictRedis(host=ip,port=6379)
          info = r.info()
          if info['role']=='master':
              master_ipaddress = ip
              break
if master_ipaddress and len(redis_hosts)>1:
    r = redis.StrictRedis(host=this_ip,port=6379)
    r.slaveof(host=master_ipaddress, port=6379)
    print 'Syncing....'
    syncing = True
    while syncing == True:
        info = r.info()
        if info['master_link_status']=='up':
            syncing = False
        time.sleep(3)
    print 'slave is connected'
os.system('touch #{Chef::Config[:file_cache_path]}/add_slave.lock')
PYCODE
not_if {File.exists?("#{Chef::Config[:file_cache_path]}/add_slave.lock")}
  end
end
