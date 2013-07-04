require "uri"
require "open-uri"
require "tempfile"

module ImageDump
  class Dumper
    def initialize url
      @url = url
      @config = Config.new
      yield @config
    end

    def dump out
      Tempfile.open("image-dump") do |tmp|
        tmp.binmode
        retrieve_url(tmp)
        cmd = @config.getCommand(tmp.path)
        puts cmd
        output = `#{cmd}`
        status = $?
        raise output if status != 0
        result = case @config.format
                 when :text
                   output
                 when :emacs
                   parse_to_elisp(output)
                 end
        out.write(result)
      end
    end

    def parse_to_elisp text_dump
      result = "(setq #{@config.options[:emacs][:varname]} '("
      parsed = parse_dump(text_dump)
      parsed.each do |hor|
        result += "("
        result += '"' + hor.map {|h| h[:hex] }.join('" "') + '"'
        result += ")\n"
      end
      result += "))\n"
      result
    end

    def parse_dump text_dump
      result = []
      x = y = 0
      pattern = /^(\d+),(\d+): +\( *(\d+), *(\d+), *(\d+)\) +(#[0-9A-F]+)/
      lines = text_dump.split("\n")
      lines.shift

      hor = []
      lines.each do |line|
        raise "unexpected output: #{line}" unless pattern =~ line
        xx = $1.to_i
        yy = $2.to_i
        r = $3.to_i
        g = $4.to_i
        b = $5.to_i
        h = $6
        if y < yy
          result << hor
          hor = []
        end
        x = xx
        y = yy
        hor << {:rgb => [r, g, b], :hex => h}
      end
      result << hor
      result
    end

    def retrieve_url out
      OpenURI.open_uri(@url) do |sio|
        out.write(sio.read)
        out.close
      end
    end
  end

  class Config
    attr_accessor :format, :options, :convert_executable, :colormap_image

    def initialize
      @format = :text
      @options = {
        :emacs => {
          :varname => "image-rgb-dump-list"
        }
      }
      @convert_executable = "convert"
      @colormap_image = nil
    end

    def getCommand image
      cmd = []
      cmd.concat([
        "#{@convert_executable}",
        "-thumbnail '32x32>'",
        "-background black",
        "-gravity center",
        "-extent 32x32",
        "-dither Riemersma"
      ])
      cmd << "-remap #{@colormap_image}" unless @colormap_image.nil?
      cmd.concat([
        "#{image}",
        "gif:- 2>&1 |",
        "#{@convert_executable} gif:- text: 2>&1"
      ])
      cmd.join(" ")
    end
  end
end
