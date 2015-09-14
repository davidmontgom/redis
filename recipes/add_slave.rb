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
node = '#{datacenter}-sentinal-#{location}-#{node.chef_environment}'
path = '/%s/' % (node)
sentinal_hosts_list = []
if zk.exists(path):
    addresses = zk.children(path)
    sentinal_hosts = list(addresses)
    for ip in sentinal_hosts:
        sentinal_hosts_list.append((ip, 26379)) 
if sentinal_hosts_list: 
  sentinel = Sentinel(sentinal_hosts_list, socket_timeout=1)
  master = sentinel.discover_master(shard)
  if master:
      master_ipaddress = master[0]
      print master_ipaddress
      rc = redis.StrictRedis(host='#{node[:ipaddress]}',port=6379)
      rc.slaveof(host=master_ipaddress, port=6379)
      print 'Syncing....'
      syncing = True
      while syncing == True:
          info = rc.info()
          print 'master_sync_in_progress:',info['master_sync_in_progress'], 'master_link_status:',info['master_link_status']
          if info['master_link_status']=='up':
              syncing = False
          time.sleep(3)
      print 'slave is connected'
os.system('touch #{Chef::Config[:file_cache_path]}/add_slave.lock')
PYCODE
not_if {File.exists?("#{Chef::Config[:file_cache_path]}/add_slave.lock")}
  end
end