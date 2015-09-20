


service "monit"
template "/etc/monit/conf.d/sentinal.conf" do
  path "/etc/monit/conf.d/sentinal.conf"
  source "monit.sentinal.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, resources(:service => "monit")
end