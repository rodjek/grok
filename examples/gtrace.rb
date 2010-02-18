# Little proof of concept script that straces a running command and tells
# you how long it's spent in each syscall (aggregated) on exit.
#
# ruby gtrace.rb <PID>

require 'rubygems'
require 'grok'

configure do |c|
  c.process = "strace -T -p #{ARGV[0]} 2>&1"
end

start do
  @syscalls = {}
end

on /(\S+)\(.* .([\d\.]+)./ do |syscall, seconds|
  if !@syscalls[syscall]
    @syscalls[syscall] = 0.0
  end
  @syscalls[syscall] += seconds.to_f
end

exit do
  @syscalls.keys.each { |syscall|
    puts "#{syscall}: #{@syscalls[syscall].to_s} seconds"
  }
end
