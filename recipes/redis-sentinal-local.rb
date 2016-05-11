package "build-essential" do
  action :install
end
package "git" do
  action :install
end

easy_install_package "boto" do
  action :install
end
easy_install_package "pytz" do
  action :install
end
easy_install_package "redis" do
  action :install
end

easy_install_package "timeout" do
  action :install
end
easy_install_package "apache-libcloud" do
  action :install
end

easy_install_package "zc.zk" do
  action :install
end

easy_install_package "psutil" do
  action :install
end

package "libffi-dev" do
  action :install
end

package "libssl-dev" do
  action :install
end

easy_install_package "paramiko" do
  options "-U"
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


bash "create_sentinal_conf_for_local" do
  cwd "/var/"
  code <<-EOH
touch /var/sentinal.conf
chmod 666 /var/sentinal.conf
cat > /var/sentinal.conf << EOL
sentinel monitor shard1 127.0.0.1 6379 1
sentinel down-after-milliseconds shard1 60000
sentinel failover-timeout shard1 180000
sentinel parallel-syncs shard1 1
EOL
EOH
  not_if {File.exists?("/var/sentinal.conf")}
end



version = '3.0.0'
bash "compile_redis_source" do
  cwd "/var/"
  code <<-EOH
wget http://download.redis.io/releases/redis-#{version}.tar.gz
tar -xvf redis-#{version}.tar.gz
cd redis-#{version}
make
EOH
  not_if {File.exists?("/var/redis-#{version}")}
end

template "/etc/supervisor/conf.d/sentinal.conf" do
  path "/etc/supervisor/conf.d/sentinal.conf"
  source "supervisord.sentinal.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  #variables({:version => '#{version}')
  notifies :restart, resources(:service => "supervisord")
end

service "supervisord"



