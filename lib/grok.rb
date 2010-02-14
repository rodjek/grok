require 'grok/watcher'

$watcher = Grok::Watcher.new

def configure(*args, &block)
  $watcher.configure(*args, &block)
end

def on(match, opts={}, &block)
  $watcher.on(match, opts, &block)
end
  
at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    $watcher.start
  end
end
