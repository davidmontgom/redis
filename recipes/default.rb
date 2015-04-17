
package "build-essential" do
  action :install
end
package "git" do
  action :install
end


directory "/data" do
    owner 'root'
    group 'root'
    mode "0777"
    recursive true
    action :create
end

directory "/data/redis" do
    owner 'root'
    group 'root'
    mode "0777"
    #recursive true
    action :create
end

=begin
package "redis-server" do
  action :install
end

service "redis-server" do
  supports :start => true, :stop => true, :restart => true
  #not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end



template "reids.conf" do
  path "/etc/redis/redis.conf"
  source "redis.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, resources(:service => "redis-server")
  #not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end
=end






version = '2.8.19'
bash "compile_redis_source" do
  cwd "/tmp/"
  code <<-EOH
wget http://download.redis.io/releases/redis-#{version}.tar.gz
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


service "redis_6379" do
  supports :start => true, :stop => true
  action :stop
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end


execute "stop-redis" do
  command "service redis_6379 stop"
  action :run
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end

template "6379.conf" do
  path "/etc/redis/6379.conf"
  source "6379.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :start, resources(:service => "redis_6379")
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

\