datacenter = node.name.split('-')[0]
environment = node.name.split('-')[1]
location = node.name.split('-')[2]
server_type = node.name.split('-')[3]
slug = node.name.split('-')[4] 
cluster_slug = File.read("/var/cluster_slug.txt")
cluster_slug = cluster_slug.gsub(/\n/, "") 

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
  subdomain = "#{server_type}-#{datacenter}-#{environment}-#{location}-#{slug}"
else
  subdomain = "#{cluster_slug}-#{server_type}-#{datacenter}-#{environment}-#{location}-#{slug}"
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


aws-development-east-zookeeper-c1-i1
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
