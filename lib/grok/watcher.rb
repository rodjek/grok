require 'rubygems'
require 'file/tail'

module Grok
  Config = Struct.new(:file, :interval, :replay, :process)
  
  class Watcher
    attr_accessor :config, :file, :interval, :match, :replay

    def initialize(&b)
      @events = {}
      @event_log = {}
      @config = Config.new(nil, 10, 0, nil)
      @catchable_signals = [:usr1, :usr2]
    end

    def configure(&b)
      b.call(@config)
    end

    def ignore(match)
      match = match.to_s if match.is_a? Integer
      (@events[:ignore] ||= []) << [Regexp.new(match)]
    end

    def on(match, opts={}, &block)
      if match.is_a? Symbol
        if @catchable_signals.include? match
          (@events[match] ||= []) << block
          puts @events
        end
      else 
        match = match.to_s if match.is_a? Integer
        within = opts[:within] ? Grok.parse_time_string(opts[:within]) : nil
        (@events[:log] ||= []) << [Regexp.new(match), block, opts[:times], within]
      end
    end

    def on_exit(&block)
      (@events[:exit] ||= []) << block
    end

    def on_start(&block)
      (@events[:start] ||= []) << block
    end

    def start
      dispatch(:start)

      if !@config.file.nil?
        File.open(@config.file) do |log|
          log.extend(File::Tail)
          log.interval = @config.interval
          log.backward(@config.replay)
          log.tail { |line|
            dispatch(:log, line)
          }
        end
      elsif !@config.process.nil?
        IO.popen(@config.process) { |fd|
          while line = fd.gets
            dispatch(:log, line)
          end
        }
      end
    end

    def stop
      dispatch(:exit)
    end

    def usr1
      dispatch(:usr1)
    end

    def usr2
      dispatch(:usr2)
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

      if event == :start
        @events[:start].each { |block| invoke block }
      elsif @catchable_signals.include? event
        @events[event].each { |block| invoke block }
      elsif handler = find(:ignore, log)
        # do nothing!
      elsif handler = find(event, log)
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
