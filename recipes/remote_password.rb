data_bag("my_data_bag")
db = data_bag_item("my_data_bag", "my")
redis_password = db[node.chef_environment]['redis']['password']

package "build-essential" do
  action :install
end
package "git" do
  action :install
end

=begin
git "/tmp/redis" do
repository "git://github.com/antirez/redis.git"
reference '2.6'
action :checkout
user "root"
not_if {File.exists?("/tmp/redis_lock")}
end
=end
version = '2.6.12'
bash "compile_redis_source" do
  cwd "/tmp/"
  code <<-EOH
wget http://redis.googlecode.com/files/redis-#{version}.tar.gz
tar -xvf redis-#{version}.tar.gz
cd redis-#{version}
make && make install
cd utils
echo "redis_6379" | sudo ./install_server.sh
EOH
  creates "/usr/local/bin/redis-server"
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock")}
end

file "#{Chef::Config[:file_cache_path]}/redis_lock" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end


service "redis_6369" do
  supports :start => true, :stop => true
  action :stop
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end


execute "stop-redis" do
  command "service redis_6379 stop"
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end

#include_recipe "runit"
#runit_service "redisd"

template "6379.conf" do
  path "/etc/redis/6379.conf"
  source "6379password.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables({
    :redis_password => "#{redis_password}",
  })
  notifies :start, resources(:service => "redis_6369")
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end

execute "start-redis" do
  command "service redis_6379 start"
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end

file "#{Chef::Config[:file_cache_path]}/redis_lock1" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end