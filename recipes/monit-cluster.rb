


service "monit"

template "/etc/monit/conf.d/redis.conf" do
  path "/etc/monit/conf.d/redis.conf"
  source "monit.redis.cluster.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "monit")
end