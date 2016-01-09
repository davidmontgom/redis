datacenter = node.name.split('-')[0]
environment = node.name.split('-')[1]
location = node.name.split('-')[2]
server_type = node.name.split('-')[3]
slug = node.name.split('-')[4] 
cluster_slug = File.read("/var/cluster_slug.txt")
cluster_slug = cluster_slug.gsub(/\n/, "") 
shard = File.read("/var/shard.txt")
shard = shard.gsub(/\n/, "") 


data_bag("meta_data_bag")
aws = data_bag_item("meta_data_bag", "aws")
domain = aws[node.chef_environment]["route53"]["domain"]
zone_id = aws[node.chef_environment]["route53"]["zone_id"]
AWS_ACCESS_KEY_ID = aws[node.chef_environment]['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = aws[node.chef_environment]['AWS_SECRET_ACCESS_KEY']


data_bag("server_data_bag")
zookeeper_server = data_bag_item("server_data_bag", "zookeeper")
required_count = zookeeper_server[datacenter][environment][location][cluster_slug]['required_count']
if cluster_slug=="nocluster"
  subdomain = "zookeeper-#{datacenter}-#{environment}-#{location}-#{slug}"
else
  subdomain = "#{cluster_slug}-zookeeper-#{datacenter}-#{environment}-#{location}-#{slug}"
end
full_domain = "#{subdomain}.#{domain}"

if datacenter!='aws'
  dc_cloud = data_bag_item("meta_data_bag", "#{datacenter}")
  keypair = dc_cloud[node.chef_environment]["keypair"]
  username = dc_cloud["username"]
end

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
zookeeper_hosts = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s-#{full_domain}:2181" % (i+1))
zk_host_str = ','.join(zookeeper_hosts)   
zk = zc.zk.ZooKeeper(zk_host_str) 
shard = open('/var/shard.txt').readlines()[0].strip()
if "#{cluster_slug}"=="nocluster":
    node = '#{datacenter}-#{node.chef_environment}-#{location}-#{server_type}-#{slug}-#{shard}'
else:
    node = '#{datacenter}-#{node.chef_environment}-#{location}-#{server_type}-#{slug}-#{cluster_slug}-#{shard}'
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
if "#{cluster_slug}"=="nocluster":
    node = '#{datacenter}-#{node.chef_environment}-#{location}-sentinel-#{slug}'
else:
    node = '#{datacenter}-#{node.chef_environment}-#{location}-sentinel-#{slug}-#{cluster_slug}'
path = '/%s/' % (node)
if zk.exists(path):
    addresses = zk.children(path)
    sentinel_servers = list(set(addresses))
    for ip_address in ssentinel_servers:
        os.system("sudo ufw allow from %s" % ip_address)
PYCODE
  end
end



if datacenter!='local' and server_type=='sentinel'
  script "zookeeper_add_sentinel" do
    interpreter "python"
    user "root"
  code <<-PYCODE
import os
import zc.zk
import logging 
logging.basicConfig()

zookeeper_hosts = []
for i in xrange(int(#{required_count})):
    zookeeper_hosts.append("%s-#{full_domain}:2181" % (i+1))
zk_host_str = ','.join(zookeeper_hosts)  
zk = zc.zk.ZooKeeper(zk_host_str)

import paramiko
username='#{username}'
if "#{cluster_slug}"=="nocluster":
    node = '#{datacenter}-#{node.chef_environment}-#{location}-sentinel-#{slug}'
else:
    node = '#{datacenter}-#{node.chef_environment}-#{location}-sentinel-#{slug}-#{cluster_slug}'
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
if "#{cluster_slug}"=="nocluster":
    node = '#{datacenter}-#{node.chef_environment}-#{location}-#{server_type}-#{slug}-#{shard}'
else:
    node = '#{datacenter}-#{node.chef_environment}-#{location}-#{server_type}-#{slug}-#{cluster_slug}-#{shard}'
for t in tree:
    if t.find(node)>=0:
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
