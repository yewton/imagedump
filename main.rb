#! /usr/bin/env ruby
require "optparse"
require "digest/sha1"
require_relative "imagedump/dumper"

RESOURCE_DIR = File.dirname(__FILE__) + "/resource"
CACHE_DIR = File.dirname(__FILE__) + "/cache"

def main(argv)
  format = :text
  opts = OptionParser.new
  emacsvar = ""
  opts.on("--emacs VARNAME") do |v|
    format = :emacs
    emacsvar = v
  end
  opts.parse!(ARGV)

  u = ARGV[0]
  abort("specify url.") if u.nil?

  begin
    url = URI.parse(u)
  rescue => e
    abort(e)
  end

  cache_ext = case format
              when :text
                "txt"
              when :emacs
                "el"
              end
  cache_basename = "imagedump-" + Digest::SHA1.hexdigest(url.to_s) + ".#{cache_ext}"
  cache_path = "#{CACHE_DIR}/#{cache_basename}"
  unless File.exists?(cache_path)
    dumper = ImageDump::Dumper.new(url) do |c|
      c.format = format
      c.convert_executable = "convert"
      c.colormap_image = "#{RESOURCE_DIR}/xterm-256colormap.gif"
      c.options[:emacs][:varname] = emacsvar
    end

    File.open(cache_path, "w") do |file|
      dumper.dump(file)
    end
  end
  puts File.expand_path(cache_path)
end

main(ARGV)
