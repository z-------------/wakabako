#!/usr/bin/env ruby

require 'base64'
require 'gist'
require 'json'
require 'net/http'
require 'toml'

### consts ###

BASE = 'https://wakatime.com/api/v1'

BAR_WIDTH = 21
BAR_EMPTY = '░'
BAR_FULL = '█'

### helper functions ###

def seppuku msg
  STDERR.puts msg
  exit 1
end

def pluralize(n, s, c = 's')
  if n == 1 then s else s + c end
end

def make_bar(p, size)
  (BAR_FULL * (p * size).round).ljust(size, BAR_EMPTY)
end

def format_duration(h, m, f)
  case f
  when :long
    "#{h} #{pluralize(h, 'hr')} #{m} #{pluralize(m, 'min')}"
  when :short
    "#{h.to_s.rjust 2}h #{m.to_s.rjust 2}m"
  else
    raise 'Invalid format specified'
  end
end

def is_b(b)
  b.instance_of? TrueClass or b.instance_of? FalseClass
end

def parse_opt(opt_str)
  m = opt_str.match /--([A-z0-9-]+)(=(\w+))?/
  if not m
    nil
  elsif m[3]
    [m[1], m[3]]
  else
    [m[1]]
  end
end

class String
  def to_b
    case self
    when 'true'
      true
    when 'false'
      false
    else
      raise 'Invalid'
    end
  end
end

def format_cols(rows, pad)
  lines = [''] * rows.length
  cols_count = rows.first.length
  widths = [0] * cols_count

  rows.each do |row|
    row.each_with_index do |item, j|
      width = item.length
      if width > widths[j]
        widths[j] = width
      end
    end
  end

  rows.each_with_index do |row, i|
    row.each_with_index do |item, j|
      lines[i] += ' ' * pad[j][0] + item.ljust(widths[j]) + ' ' * pad[j][1]
    end
  end

  lines
end

### parse options ###

opts = {
  dry: false,
  format: :long,
  help: false,
  'include-percent': false,
  'relative-bars': false
}

ARGV.each do |arg|
  p = parse_opt arg
  next if not p

  key = p[0].to_sym
  val_str = p[1]

  if not opts.include? key
    puts "Ignoring unknown option '#{key}'."
    next
  end

  if is_b opts[key]
    if not val_str
      val = true
    else
      val = val_str.to_b
    end
  else
    if not val_str
      seppuku "Invalid value given for option '#{key}'"
    end
    val = val_str.to_sym
  end

  opts[key] = val
end

### main ###

if opts[:help]
  help = <<-HELP
Options:
  --dry             Print to stdout instead of uploading a gist.    [boolean] [default=false]
  --format=FORMAT   Control duration format. FORMAT can be `short'
                    or `long'.                                       [string] [default=short]
  --include-percent Include a percentage after each bar.            [boolean] [default=false]
  --relative-bars   Scale bars relative to the most used language
                    instead of the sum of all languages used.       [boolean] [default=false]
  HELP
  puts help
  exit
end

config = TOML.load_file("#{__dir__}/config.toml")
auth_key_hashed = Base64.encode64(config['auth_key']).chomp

uri = URI("#{BASE}/users/#{config['user']}/stats/last_7_days")
req = Net::HTTP::Get.new(uri)
req['Authorization'] = "Basic #{auth_key_hashed}"

res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
  http.request(req)
end

table = []
JSON.parse(res.body)['data']['languages'][0...5].each_with_index do |language, i|
  row = []

  hours = language['hours']
  mins = language['minutes']
  percent = language['percent']
  time_str = format_duration(hours, mins, opts[:format])

  if opts[:'relative-bars']
    if i == 0
      $percent_max = percent
      bar = make_bar(1, BAR_WIDTH)
    else
      bar = make_bar(percent / $percent_max, BAR_WIDTH)
    end
  else
    bar = make_bar(percent / 100, BAR_WIDTH)
  end

  row << language['name'] << time_str << bar
  if opts[:'include-percent']
    row << "#{percent.round.to_s.rjust 2}%"
  end
  table << row
end

lines = format_cols(table, [[0, 2], [0, 1], [0, 0], [1, 0]])
if lines.empty?
  lines << 'Nothing here.'
end

formatted = lines.join("\n") + "\n"

if opts[:dry]
  puts formatted
else
  Gist.gist(formatted, {
    update: config['gist_id'],
    filename: config['title']
  })
end
