require 'grok/watcher'
require 'grok/time'

$watcher = Grok::Watcher.new

def configure(*args, &block)
  $watcher.configure(*args, &block)
end

def on(match, opts={}, &block)
  $watcher.on(match, opts, &block)
end

def exit(&block)
  $watcher.on_exit(&block)
end

def start(&block)
  $watcher.on_start(&block)
end

trap "SIGINT", proc { $watcher.stop }

at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    $watcher.start
  end
end
