
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

version = '3.0.0'
bash "compile_redis_source" do
  cwd "/var/"
  code <<-EOH
wget http://download.redis.io/releases/redis-#{version}.tar.gz
tar -xvf redis-#{version}.tar.gz
EOH
  not_if {File.exists?("/var/redis-#{version}")}
end
