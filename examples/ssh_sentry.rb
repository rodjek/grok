require 'grok'

configure do |c|
  c.file = "/var/log/auth.log"
  c.interval = 5
  c.replay = 0
end

on /Failed password for root from ([\d\.]+)/, :times => 3, :within => '2m' do |ip|
  ret = `/sbin/iptables -I INPUT --source #{ip} -j REJECT`
end
