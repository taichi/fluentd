require 'fluent/detect'

require 'gson' if jruby?

# Monkey patch for JRuby
module Yajl
  class Parser
    attr_accessor :on_parse_complete
    
    def initialize
      @delegate = Gson::Decoder.new
      @delegate.on_document do |doc|
        unless @on_parse_complete.nil?
          on_parse_complete.call(doc)
        end
      end
      
    end
    
    def << (data)
      @delegate.decode(data)
    end
  end
end if jruby?
