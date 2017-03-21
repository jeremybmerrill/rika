# encoding: utf-8

raise "You need to run JRuby to use Rika" unless RUBY_PLATFORM =~ /java/

require "rika/version"
require 'uri'
require 'net/http'
require 'java'

Dir[File.join(File.dirname(__FILE__), "../target/dependency/*.jar")].each do |jar|
  require jar
end

$rika_tika ||= nil

# Heavily based on the Apache Tika API: http://tika.apache.org/1.5/api/org/apache/tika/Tika.html
module Rika
  import org.apache.tika.metadata.Metadata
  import org.apache.tika.Tika
  import org.apache.tika.language.LanguageIdentifier
  import org.apache.tika.detect.DefaultDetector
  import java.io.FileInputStream
  import java.net.URL
  import org.apache.tika.sax.BodyContentHandler;
  import org.apache.tika.parser.AutoDetectParser;
  import org.apache.tika.parser.ParseContext;
  import org.apache.tika.parser.html.BoilerpipeContentHandler;

  import org.apache.tika.language.translate.GoogleTranslator 




  def self.parse_content_and_metadata(file_location, max_content_length = -1)
    parser = Parser.new(file_location, max_content_length)
    [parser.content, parser.metadata]
  end

  def self.parse_content(file_location, max_content_length = -1)
    parser = Parser.new(file_location, max_content_length)
    parser.content
  end

  def self.parse_main_content(file_location, max_content_length = -1)
    parser = Parser.new(file_location, max_content_length)
    parser.main_content
  end

  def self.parse_metadata(file_location)
    parser = Parser.new(file_location, 0)
    parser.metadata
  end

  class Parser

    def initialize(file_location, max_content_length = -1, detector = DefaultDetector.new)
      @uri = file_location
      $rika_tika = @tika = if $rika_tika.nil?
                              puts "creating a new Tika"
                              Tika.new(detector)
                           else
                              $rika_tika
                           end
      @tika.set_max_string_length(max_content_length)
      @metadata_java = Metadata.new
      @metadata_ruby = nil
      @input_type = get_input_type
    end

    def content
      self.parse!
      @content
    end

    def main_content
      self.parse_main_content!
      @main_content
    end

    def metadata
      unless @metadata_ruby
        self.parse!
        @metadata_ruby = {}

        @metadata_java.names.each do |name|
          @metadata_ruby[name] = @metadata_java.get(name)
        end
      end
      @metadata_ruby
    end

    def media_type
      if file?
        @media_type ||= @tika.detect(java.io.File.new(@uri))
      else
        @media_type ||= @tika.detect(input_stream)
      end
    end

    def available_metadata
      metadata.keys
    end

    def metadata_exists?(name)
      metadata[name] != nil
    end

    def file?
      @input_type == :file
    end

    def language
      @lang ||= LanguageIdentifier.new(content)

      @lang.language
    end

    def language_is_reasonably_certain?
      @lang ||= LanguageIdentifier.new(content)

      @lang.is_reasonably_certain
    end

    protected

    def parse!
      @content ||= @tika.parse_to_string(input_stream, @metadata_java).to_s.strip
    end

    def parse_main_content!
      text_handler = BodyContentHandler.new 
      auto_detect_parser = AutoDetectParser.new 
      context = ParseContext.new 
      auto_detect_parser.parse(input_stream, BoilerpipeContentHandler.new(text_handler), @metadata_java, context);
      @main_content = text_handler.to_s
    end

    def get_input_type
      if File.exists?(@uri) && File.directory?(@uri) == false
        :file
      elsif URI(@uri).scheme.to_s.match(%r{https?})
        :http
      else
        raise IOError, "Input (#{@uri}) is neither file nor http."
      end
    end

    def input_stream
      if file?
        FileInputStream.new(java.io.File.new(@uri))
      else # :http
        URL.new(@uri).open_stream
      end
    end
  end

  class Translator
    def initialize
      @translator = GoogleTranslator.new
    end

    def translate(inputtext, source='ru', target='en')
      # begin
        puts "translating #{inputtext.size} chars to #{target} at a cost of $#{(inputtext.size / 50000.0).round(2)}"
        return @translator.translate(inputtext, source, target);
      # rescue StandardError
      #   return "Error while translating.";
      # end
    end
  end
end
