#!/usr/bin/env ruby
# coding: utf-8
#
# See LICENSE.txt for licensing information.

VERSION = '0.7'

# Colors, RGBA hex (alpha works if you'd like transparent grid/origin)
CBG     = 0x000000ff # black
CFG     = 0xffffffff # white
CGRID   = 0xff0000ff # red
CORIGIN = 0x00ff00ff # green
CNOTE   = 0x0000ffff # blue

@conf = {
  mapx: 180, mapy: 180, level: 10, scale: 2, verbose: false,
  grid: true, origin: true, notes: false
}

## Guts

# Handy struct for keeping general information about overmap
# seen data
Overview = Struct.new(:seen, :width, :height, :n, :s, :w, :e)
class Overview
  def any?; seen.keys.any?; end
  def to_s
    "Overview: #{width}x#{height} overmaps: #{seen.keys.length}"
  end
end

# Handy struct for keeping notes data
Note = Struct.new(:text, :color, :symbol, :x, :y)

# Print stuff only if verbose is on
def verbose(&blk)
  return unless @conf[:verbose]
  puts blk.call
end

# Find seen files and record overview data
def overview(save_path)
  seen = Hash.new
  n = w = s = e = 0

  Dir.glob(File.join(save_path, '#*.seen.*')).each do |f|
    x, y = f.match(/seen\.(-?\d+)\.(-?\d+)$/).captures.map(&:to_i)
    seen["#{x} #{y}"] = f
    w = x if x < w
    e = x if x > e
    n = y if y > n
    s = y if y < s
  end

  width = e + w.abs + 1
  height = n + s.abs + 1

  Overview.new(seen, width, height, n, s, w, e)
end

# Extract chosen level raw data from a seen file and call the data parsing
# function on it
def parse_seen(path)
  data = File.open(path) do |fh|
    fh.each_line do |line|
      next unless line.match(/L #{@conf[:level]}/)
      break fh.readline.chop
    end
  end

  parse_seen_data(data)
end

# Extract chosen level notes from a seen file
def parse_notes(path)
  notes = Array.new
  File.open(path) do |fh|
    fh.each_line do |line|
      next unless line.match(/L #{@conf[:level]}/)
      3.times { fh.readline }
      break
    end
    fh.each_line do |line|
      break unless m = line.match(/N (\d+) (\d+)/)
      x, y = m.captures.map(&:to_i)
      n = parse_note(fh.readline.chop)
      n.x = x
      n.y = y
      notes.push(n)
    end
  end
  notes
end

# Transform the raw seen data into an array of arrays of box coordinates for
# drawing
#
# Box coordinates are overmap-local and unscaled. Does translate the RLE
# into a set of 'scan lines', so to say...
def parse_seen_data(data)
  boxes = Array.new
  position = 0

  data.scan(/\d+ \d+/).map do |e|
    visited, len = e.split.map(&:to_i)

    if visited == 1
      x0 = position % @conf[:mapx]
      y0 = position / @conf[:mapx]
      x1 = (position + len - 1) % @conf[:mapx]
      y1 = (position + len - 1) / @conf[:mapx]

      # split into 'scan lines' if needed
      if y0 != y1
        boxes.push([x0, y0, @conf[:mapx]-1, y0])
        (y0+1).upto(y1).each do |sy|
          if sy == y1
            boxes.push([0, sy, x1, sy])
          else
            boxes.push([0, sy, @conf[:mapx]-1, sy])
          end
        end
      else
        boxes.push([x0, y0, x1, y1])
      end
    end

    position += len
  end

  boxes
end

# Parse note
def parse_note(data)
  color = symbol = nil
  arg_a, arg_b, text = data.match(/(.[:|;])?(.[:|;])?(.*)/).captures
  [arg_a, arg_b].compact.each do |a|
    if a.end_with? ';'
      color = a[0].downcase.to_sym
    else
      symbol = a[0]
    end
  end

  Note.new(text, color, symbol)
end

# Drawing loop helper
#
# As wee need to convert a number of coordinates it seems better to extract
# the loop logic.
#
# x, y - overmap coordinates
# ix, iy - image coordinates
def draw_loop(overview, &blk)
  iy = 0
  overview.s.upto(overview.n).each do |y|
    ix = 0
    overview.w.upto(overview.e).each do |x|
      blk.call(x, y, ix, iy)
      ix += 1
    end
    iy += 1
  end
end

# Transform box to image coordinates for given overmap
def box_transform(box, ix, iy)
  box[0] = (ix * XO) + (box[0] * @conf[:scale])
  box[1] = (iy * YO) + (box[1] * @conf[:scale])
  box[2] = (ix * XO) + ((box[2]+1) * @conf[:scale])
  box[3] = (iy * YO) + ((box[3]+1) * @conf[:scale])

  box
end

# Draw seen
#
# The main drawing loop
def draw_seen(image, overview)
  draw_loop(overview) do |x, y, ix, iy|
    verbose { "At overmap #{x}x#{y}..." }
    next unless overview.seen.has_key? "#{x} #{y}"
    parse_seen(overview.seen["#{x} #{y}"]).each do |box|
      image.rect(*box_transform(box, ix, iy), CFG, CFG)
    end
  end
end

# Draw notes
def draw_notes(image, overview)
  draw_loop(overview) do |x, y, ix, iy|
    verbose { "At overmap #{x}x#{y}..." }
    next unless overview.seen.has_key? "#{x} #{y}"
    parse_notes(overview.seen["#{x} #{y}"]).each do |note|
      image.rect(*box_transform([note.x, note.y, note.x, note.y], ix, iy), CNOTE, CNOTE)
    end
  end
end

# Draw grid
def draw_grid(image, overview)
  draw_loop(overview) do |x, y, ix, iy|
    image.rect(ix*XO, iy*YO, (ix+1)*XO-1, (iy+1)*YO-1, CGRID)
  end
end

# Draw origin
def draw_origin(image, overview)
  draw_loop(overview) do |x, y, ix, iy|
    next unless x == 0 && y == 0
    image.rect(ix*XO+1, iy*YO+1, (ix+1)*XO-2, (iy+1)*YO-2, CORIGIN)
  end
end

## Main

if __FILE__ == $0
  begin
    require 'optparse'

    op = OptionParser.new do |o|
      o.banner = "Usage:\t#{$PROGRAM_NAME} [option...] save_path name.png\n\tVersion: #{VERSION}\n\n"
      o.on('-h', '--help', 'Display this message') { puts o; exit }
      o.on('-v', '--verbose', 'Enable debug output') { @conf[:verbose] = true }
      o.on('-x', '--mapx MAPX', Integer, 'Set overmap width (MAPX)') {|a| @conf[:mapx] = a }
      o.on('-y', '--mapy MAPY', Integer, 'Set overmap height (MAPY)') {|a| @conf[:mapy] = a }
      o.on('-l', '--level L', Integer, 'Set map layer (L)') {|a| @conf[:level] = a }
      o.on('-s', '--scale INT', Integer, 'Set pixel scale') {|a| @conf[:scale] = a }
      o.on('-g', '--[no-]grid', 'Draw grid') {|a| @conf[:grid] = a }
      o.on('-o', '--[no-]origin', 'Draw origin') {|a| @conf[:origin] = a }
      o.on('-n', '--[no-]notes', 'Draw notes') {|a| @conf[:notes] = a }
    end
    op.parse!

    unless ARGV.length == 2
      puts op
      exit(2)
    end

    PATH = ARGV.shift
    OUTPUT = ARGV.shift

    # x,y scale/offset consts
    XO = @conf[:mapx] * @conf[:scale]
    YO = @conf[:mapy] * @conf[:scale]

    puts 'Processing... (this may take some time)'

    verbose { 'Gathering seen data...' }
    overview = overview(PATH)
    verbose { overview.to_s }

    unless overview.any?
      puts 'Didn\'t find any seen data.'
      exit(2)
    end

    require 'chunky_png'
    image = ChunkyPNG::Image.new(overview.width * XO, overview.height * YO, CBG)

    verbose { 'Drawing seen data...' }
    draw_seen(image, overview)

    verbose { 'Drawing additional stuff...' }
    draw_notes(image, overview) if @conf[:notes]
    draw_grid(image, overview) if @conf[:grid]
    draw_origin(image, overview) if @conf[:origin]

    verbose { 'Saving image...' }
    image.save(OUTPUT)
    puts 'Done.'
  rescue StandardError => e
    STDERR.puts "Error: #{e.to_s}"
    STDERR.puts "Stack: #{e.backtrace.join("\n")}" if @conf[:verbose]
    exit(3)
  end
end
