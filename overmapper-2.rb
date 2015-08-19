#!/usr/bin/env ruby
# coding: utf-8

require 'oj'

module OverMapper
  class Error < StandardError; end

  class Converter
    LINES = {
      4194424 => "\u2502",
      4194417 => "\u2500",
      4194413 => "\u2514",
      4194412 => "\u250C",
      4194411 => "\u2510",
      4194410 => "\u2518",
      4194420 => "\u251C",
      4194422 => "\u2534",
      4194421 => "\u2524",
      4194423 => "\u252C",
      4194414 => "\u253C",
    }
    ROADS = {
      'north' => "│",
      'south' => "│",
      'west' => "─",
      'east' => "─",
      'nesw' => "┼",
      'ns' => "│",
      'ew' => "─",
      'wn' => "┘",
      'ne' => "└",
      'sw' => "┐",
      'es' => "┌",
      'esw' => "┬",
      'nsw' => "┤",
      'new' => "┴",
      'nes' => "├",
    }
    DIRS = %w{north east south west ns ew sn we}
    HTML_START = """<html><head><style>
body { background: black; color: #aaaaaa; }
.cl_white { color: #ffffff; }
.cl_blue { color: #0000ff; }
.cl_red { color: #ff0000; }
.cl_brown { color: #a52a2a; }
.cl_green { color: #008000; }
.cl_cyan { color: #00ffff; }
.cl_dark_gray { color: #a9a9a9; }
.cl_magenta { color: #ff00ff; }
.cl_yellow { color: #ffff00; }
.cl_light_blue { color: #add8e6; }
.cl_light_green { color: #90ee90; }
.cl_light_red { color: #ff5555; }
.cl_i_ltred { color: black; background: #ff5555; }
.cl_light_gray { color: #d3d3d3; }
.cl_i_ltgray { color: black; background: #d3d3d3; }
.cl_light_cyan { color: #e0ffff; }
.cl_ltgray_yellow { color: #d3d3d3; background: #ffff00; }
.cl_pink { color: #ffc0cb; }
.cl_yellow_magenta { color: #ffff00; background: #ff00ff; }
.cl_white_magenta { color: #ffffff; background: #ff00ff; }
.cl_i_magenta { color: black; background: #ff00ff; }
.cl_pink_magenta { color: #ffc0cb; background: #ff00ff;  }
.cl_i_green { color: black; background: #008000; }
.cl_i_brown { color: black; background: #a52a2a; }
.cl_h_yellow { color: #ffff00; background: #0000ff; }
.cl_h_dkgray { color: #a9a9a9; background: #0000ff; }
.cl_i_ltblue { color: black; background: #add8e6; }
.cl_i_blue { color: black; background: #0000ff; }
.cl_i_red { color: black; background: #ff0000; }
.cl_ltgreen_yellow { color: #d3d3d3; background: #ffff00; }
.cl_white_white { background: white; }
.cl_i_ltcyan { color: black; background: #e0ffff; }
.cl_yellow_cyan { color: #ffff00; background: #00ffff; }
</style></head><body><pre>"""
    HTML_END = """</pre></body></html>"""
    FORMATS = %i{txt html}

    attr_accessor :data, :path

    def initialize(data_path, logger: nil)
      @logger = logger
      @data   = nil
      @path   = File.join(data_path, 'terrain.dat')

      if File.exists? @path
        load_data(@path)
      else
        log :warn, 'No data file found'
      end
    end

    def preprocess(cdda_path)
      in_paths = ([File.join(cdda_path, 'data/json/overmap_terrain.json')] + \
                  Dir.glob(File.join(cdda_path, 'data/json/mapgen/*.json')))

      log :debug, 'Preprocessing terrain data'
      @data = Hash.new
      in_paths.each do |p|
        Oj.load_file(p).each do |e|
          next if (e['id'].nil? || e['color'].nil? || e['sym'].nil?)

          begin
            id    = e['id']
            color = e['color']
            syms  = process_sym(e['sym'])
            tile  = {syms: syms, color: color}

            if @data.has_key? id
              log :warn, "Duplicate terrain id #{id}"
            end

            @data[id] = tile
          rescue StandardError => error
            log :error, e.pretty_inspect
            log :error, error.pretty_inspect
          end
        end
      end
      log :info, 'Saving terrain data'
      File.open(@path, 'wb') {|f| f.write(Marshal.dump(@data)) }
    end

    def load_data(dat_path)
      @data = File.open(dat_path, 'rb') {|f| Marshal.load(f) }
    end

    def convert(dir_path, format: :html, width: 180, height: 180, layer: 10)
      unless @data
        raise Error, 'No terrain.dat loaded'
      end
      unless FORMATS.include? format
        raise ArgumentError, "Unknown format: #{format}"
      end

      empty_line = ' ' * width
      maps = get_maps(dir_path).collect do |row|
        row.collect do |map|
          unless map
            next Array.new(height, empty_line)
          end

          data = get_layer(map, layer)
          strings = Array.new
          line = String.new
          pos = 0

          data.each do |id, len|
            sym, color = get_tile_data(id)
            if format == :html
              # does not care about proper Unicode glyphs
              if sym == '<'
                sym = '&#x3c;'
              elsif sym == '>'
                sym = '&#x3e;'
              end
            end
            while len > 0
              line_left = width - pos
              how_many = [line_left, len].min
              if format == :html && color
                line += "<span class=\"cl_#{color}\">"
              end
              line += sym * how_many
              if format == :html && color
                line += '</span>'
              end
              pos += how_many
              len -= how_many
              if pos == width
                strings.push(line)
                line = String.new
                pos = 0
              end
            end
          end

          strings
        end.transpose.collect(&:join)
      end

      if format == :html
        puts HTML_START
      end
      maps.each {|m| puts m }
      if format == :html
        puts HTML_END
      end
    end

    private

    def get_tile_data(id)
      tile = @data[id]
      if tile
        return [tile[:syms].first, tile[:color]]
      else
        parts = id.split('_')
        suffix = parts.pop
        nid = parts.join('_')

        if nid == 'road'
          sym = ROADS[suffix]
          unless sym
            log :warn, "No road for suffix #{suffix}"
            return ['?', nil]
          end
        else
          tile = @data[nid]
          unless tile
            log :warn, "Tile not found #{id} (#{nid} #{suffix})"
            return ['?', nil]
          end
          dir = DIRS.index(suffix) % 4 rescue 0
          sym = tile[:syms][dir] || tile[:syms].first
          color = tile[:color]
        end
      end
      [sym, color]
    end

    def get_layer(json_path, layer)
      raw = File.read(json_path).lines
      header = raw.shift
      unless header.match(/# version 25/)
        raise Error, "Unknown header: #{header}"
      end

      Oj::Doc.open(raw.join("\n")) {|d| d.fetch("/layers/#{layer + 1}") }
    end

    def get_maps(dir_path)
      paths = Dir.glob(File.join(dir_path, 'o.*'))
      if paths.empty?
        raise Error, 'No maps found'
      end

      coords = Array.new
      seen   = Hash.new
      paths.each do |p|
        x, y = p.match(/o.(-?\d+).(-?\d+)/).captures.map(&:to_i)
        coords.push([x, y])
        seen["#{x} #{y}"] = p
      end

      coords = coords.transpose
      min_x, max_x = coords.first.minmax
      min_y, max_y = coords.last.minmax

      min_y.upto(max_y).collect do |y|
        min_x.upto(max_x).collect do |x|
          seen["#{x} #{y}"]
        end
      end
    end

    def process_sym(raw)
      if raw.nil?
        log :warn, 'No raw symbol given'
        return ['?']
      end

      [raw].flatten.collect do |r|
        if r <= 255
          r.chr
        else
          if LINES.has_key? r
            LINES[r]
          else
            log :warn, 'Raw symbol not found in LINES'
            '?'
          end
        end
      end
    end

    def log(level, msg)
      if @logger
        @logger.send(level, msg)
      end
    end
  end
end

# provide a really dumb user interface
if __FILE__ == $0
  def usage
    STDERR.puts """Usage:
      #{$0} preprocess /path/to/cdda_dir

      Convert CDDA overmap terrain data for later use.
      File 'terrain.dat' will be created in current directory.
      NOTE: You need to have that file for convert to work.

      #{$0} convert [format] /path/to/save_dir
      
      format: html, txt. default: html
      
      This will try to convert overmap data to given format.
      It will output to stdout so you better redirect it to a file."""
    exit(2)
  end

  cmd, *args = ARGV
  unless cmd == 'preprocess' || cmd == 'convert'
    usage
  end

  require 'logger'
  logger = Logger.new(STDERR)
  logger.level = Logger::DEBUG
  logger.formatter = lambda {|s, d, p, m| "#{d} #{s} -- #{m}\n" }

  cn = OverMapper::Converter.new(File.absolute_path('./'), logger: logger)
  if cmd == 'preprocess'
    cn.preprocess(args.first)
  else
    format = :html
    if args.length > 1
      unless ['html', 'txt'].include? args.first
        usage
      end
      format = args.shift.to_sym
    end
    cn.convert(File.absolute_path(args.first), format: format)
  end
end
