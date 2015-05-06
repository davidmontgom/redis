
package "build-essential" do
  action :install
end
package "git" do
  action :install
end

bash "set_limits" do
  cwd "/tmp/"
  code <<-EOH
    ulimit -Sn 100000
    sysctl -w fs.file-max=100000
    touch #{Chef::Config[:file_cache_path]}/redis_sysctl.lock
  EOH
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_sysctl.lock")}
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


version = '3.0.0'
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
  source "redis-3-6379.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :start, resources(:service => "redis_6379")
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end



bash "start-redis" do
  cwd "/tmp/"
  code <<-EOH
    service redis_6379 start
    touch #{Chef::Config[:file_cache_path]}/redis_lock1
  EOH
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis_lock1")}
end

