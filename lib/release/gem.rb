# frozen_string_literal: true

require 'toolrack'
require 'teLogger'

require 'tty/prompt'
require 'colorize'
require 'tty/command'


require_relative "gem/version"
require_relative 'gem/gem_engine'


module Release
  module Gem
    class Error < StandardError; end
    class Abort < StandardError; end
    # Your code goes here...

    def self.q(msg)
      "\n #{msg}\n".yellow
    end

    def self.engine(eng, *args, &block)
      case eng
      when :gem
        Engine::GemEngine.new(*args, &block)
      end
    end

    # caller user log
    def self.cul(pmt,msg)
      pmt.puts " ==> #{msg} ".yellow  if not pmt.nil?
    end

    # caller user error
    def self.cue(pmt, msg)
      pmt.puts " ==x #{msg}".red if not pmt.nil?
    end

    def self.format_dt(dt)
      dt.strftime("%d %b %Y (%a), %H:%M:%S:%L")
    end

    def self.logger
      if @_logger.nil?
        @_logger = TeLogger::Tlogger.new
        @_logger.tag = :gem_rel
      end
      @_logger
    end


  end
end


# load the rake tasks
rf = File.join(File.dirname(__FILE__),"Rakefile")
load rf
