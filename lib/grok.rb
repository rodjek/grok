require 'grok/watcher'

$watcher = Grok::Watcher.new

%w(configure on).each do |method|
  eval(<<-EOF)
    def #{method}(*args, &block)
      $watcher.#{method}(*args, &block)
    end
  EOF
end

at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    $watcher.start
  end
end
