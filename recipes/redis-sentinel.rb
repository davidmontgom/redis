
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
  action :upgrade
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

easy_install_package "paramiko" do
  action :install
end


cookbook_file "/var/sentinal-master-zk.py" do
  source "sentinal-master-zk.py"
  mode 00744
end

cookbook_file "/var/sentinal-zookeeper.py" do
  source "sentinal-zookeeper.py"
  mode 00744
end 

=begin
bash "sentinal-master" do
  cwd "/tmp/"
  code <<-EOH
    /usr/bin/python /var/sentinal-master-zk.py
    touch "#{Chef::Config[:file_cache_path]}/sentinal.lock"
  EOH
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/sentinal.lock")}
end
=end

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


execute "restart_supervisorctl_sentinal-zookeeper" do
  command "sudo supervisorctl restart sentinal_zookeeper_server:"
  action :nothing
end

execute "restart_supervisorctl_sentinal-master" do
  command "sudo supervisorctl restart sentinal_master_server:"
  action :nothing
end

=begin
template "/etc/supervisor/conf.d/sentinal-zookeeper.conf" do
  path "/etc/supervisor/conf.d/sentinal-zookeeper.conf"
  source "supervisord.sentinal-zookeeper.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :run, "execute[restart_supervisorctl_sentinal-zookeeper]"
end
=end

template "/etc/supervisor/conf.d/sentinal-master.conf" do
  path "/etc/supervisor/conf.d/sentinal-master.conf"
  source "supervisord.sentinal-master.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :run, "execute[restart_supervisorctl_sentinal-master]"
end

service "supervisord"



