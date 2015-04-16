
easy_install_package "psutil" do
  action :install
end

package "python-redis" do
  action :install
end

script "server_ram" do
  interpreter "python"
  user "root"
code <<-PYCODE
import psutil
import redis
import os
phymem = psutil.phymem_usage()
ram = phymem.total 
r = redis.StrictRedis()
r.set('server_total_memory',ram)
os.system("touch /var/chef/cache/redis-ram.lock")
PYCODE
  not_if {File.exists?("#{Chef::Config[:file_cache_path]}/redis-ram.lock")}
end