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
  script "zookeeper_add_redis" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import os
import zc.zk
import logging 
logging.basicConfig()
import paramiko
import time
username='#{username}'
zookeeper_hosts = '#{zk_hosts}'
zk_host_list = '#{zk_hosts}'.split(',')
for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
zk = zc.zk.ZooKeeper(zk_host_str) 
ip_address_list = zookeeper_hosts.split(',')
shard = open('/var/shard.txt').readlines()[0].strip()
node = '#{datacenter}-redis-#{location}-#{node.chef_environment}-%s' % (shard)
path = '/%s/' % (node)
#Each redis server will access each other in the same shard
if zk.exists(path):
    addresses = zk.children(path)
    redis_servers = list(set(addresses))
    print redis_servers
    for ip_address in redis_servers:
        if ip_address != '#{node[:ipaddress]}':
          keypair_path = '/root/.ssh/#{keypair}'
          key = paramiko.RSAKey.from_private_key_file(keypair_path)
          ssh = paramiko.SSHClient()
          ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
          ssh.connect(ip_address, 22, username=username, pkey=key)
          cmd = "sudo ufw allow from #{node[:ipaddress]}"
          stdin, stdout, stderr = ssh.exec_command(cmd)
          ssh.close()
          os.system("sudo ufw allow from %s" % ip_address)
          
 
#Eash sentinal server can access this node     
node = '#{datacenter}-sentinal-#{location}-#{node.chef_environment}'
path = '/%s/' % (node)
if zk.exists(path):
    addresses = zk.children(path)
    sentinal_servers = list(set(addresses))
    for ip_address in sentinal_servers:
        os.system("sudo ufw allow from %s" % ip_address)
PYCODE
  end
end



if datacenter!='local' and server_type=='sentinal'
  script "zookeeper_add_sentinal" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import os
import zc.zk
import logging 
logging.basicConfig()

zk_host_list = '#{zk_hosts}'.split(',')
for i in xrange(len(zk_host_list)):
    zk_host_list[i]=zk_host_list[i]+':2181' 
zk_host_str = ','.join(zk_host_list)
zk = zc.zk.ZooKeeper(zk_host_str)

import paramiko
username='#{username}'
zookeeper_hosts = '#{zk_hosts}'
ip_address_list = zookeeper_hosts.split(',')
node = '#{datacenter}-sentinal-#{location}-#{node.chef_environment}'
path = '/%s/' % (node)
this_ip = '#{node[:ipaddress]}'
if zk.exists(path):
    addresses = zk.children(path)
    sentinal_servers = list(set(addresses))
    for ip_address in sentinal_servers:
        if ip_address != this_ip:
          keypair_path = '/root/.ssh/#{keypair}'
          key = paramiko.RSAKey.from_private_key_file(keypair_path)
          ssh = paramiko.SSHClient()
          ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
          ssh.connect(ip_address, 22, username=username, pkey=key)
          cmd = "sudo ufw allow from #{node[:ipaddress]}"
          stdin, stdout, stderr = ssh.exec_command(cmd)
          ssh.close()
          os.system("sudo ufw allow from %s" % ip_address)

this_tree = str(zk.export_tree()).strip()
tree = this_tree.splitlines()
shard_list = []
for t in tree:
    if t.find('shard')>=0 and t.find('redis')>=0:
        shard_list.append(str(t))
for node in shard_list:
  path = '/%s/' % (node)
  if zk.exists(path):
      addresses = zk.children(path)
      redis_servers = list(set(addresses))
      for ip_address in redis_servers:
          keypair_path = '/root/.ssh/#{keypair}'
          key = paramiko.RSAKey.from_private_key_file(keypair_path)
          ssh = paramiko.SSHClient()
          ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
          ssh.connect(ip_address, 22, username=username, pkey=key)
          cmd = "sudo ufw allow from #{node[:ipaddress]}"
          stdin, stdout, stderr = ssh.exec_command(cmd)
          ssh.close()
PYCODE
  end
end
