require 'rubygems'
require 'file/tail'

module Grok
  Config = Struct.new(:file, :interval, :replay)
  
  class Watcher
    attr_accessor :config, :file, :interval, :match, :replay

    def initialize(&b)
      @events = {}
      @config = Config.new("/var/log/messages", 10)

      #instance_eval(&b) if block_given?
    end

    def configure(&b)
      b.call(@config)
    end

    def on(match, opts={}, &block)
      event = :log
      match = match.to_s if match.is_a? Integer
      (@events[event] ||= []) << [Regexp.new(match), block]
    end

    def dispatch(event, log)
      if handler = find(event, log)
        regexp, block = *handler
        self.match = log.match(regexp).captures
        invoke block
      end
    end

    def start
      File.open(@config.file) do |log|
        log.extend(File::Tail)
        log.interval = @config.interval
        log.backward(@config.replay)
        log.tail { |line|
          dispatch(:log, line)
        }
      end
    end

  private
    def find(type, log)
      if events = @events[type]
        events.detect {|regexp,_|
          log.match(regexp)
        }
      end
    end

    def invoke(block)
      mc = class << self; self; end
      mc.send :define_method, :__grok_event_handler, &block

      bargs = case block.arity <=> 0
        when -1; match
        when 0; []
        when 1; match[0..block.arity-1]
      end

      catch(:halt) {
        __grok_event_handler(*bargs)
      }
    end
  end
end
