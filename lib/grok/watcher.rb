require 'rubygems'
require 'file/tail'

module Grok
  Config = Struct.new(:file, :interval, :replay)
  
  class Watcher
    attr_accessor :config, :file, :interval, :match, :replay

    def initialize(&b)
      @events = {}
      @event_log = {}
      @config = Config.new("/var/log/messages", 10, 0)

      #instance_eval(&b) if block_given?
    end

    def configure(&b)
      b.call(@config)
    end

    def on(match, opts={}, &block)
      match = match.to_s if match.is_a? Integer
      within = opts[:within] ? Grok.parse_time_string(opts[:within]) : nil
      (@events[:log] ||= []) << [Regexp.new(match), block, opts[:times], within]
    end

    def exit(&block)
      (@events[:exit] ||= []) << block
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

    def stop
      dispatch(:exit)
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

    def dispatch(event, log=nil)
      if event == :exit
        @events[:exit].each { |block| invoke block }
        Process.exit
      end

      if handler = find(event, log)
        regexp, block, times, within = *handler
        self.match = log.match(regexp).captures
        (@event_log[match] ||= []) << Time.now.to_i
        if @event_log[match].length >= times.to_i
          if within:
            times_within_range = @event_log[match].reject { |event_time|
              event_time < (Time.now.to_i - within)
            }
            if times_within_range.length >= times.to_i
              invoke block
              @event_log[match].clear
            end
          else
            invoke block
            @event_log[match].clear
          end
        end
      end
    end
  end
end
