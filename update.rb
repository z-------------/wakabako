#!/usr/bin/env ruby

require 'base64'
require 'gist'
require 'json'
require 'net/http'
require 'toml'

### consts ###

BASE = 'https://wakatime.com/api/v1'

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
  m = opt_str.match /--(\w+)(=(\w+))?/
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

### parse options ###

opts = {
  format: :long,
  dry: false
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

config = TOML.load_file("#{__dir__}/config.toml")
auth_key_hashed = Base64.encode64(config['auth_key']).chomp

uri = URI("#{BASE}/users/#{config['user']}/stats/last_7_days")
req = Net::HTTP::Get.new(uri)
req['Authorization'] = "Basic #{auth_key_hashed}"

res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
  http.request(req)
end

lines = []
JSON.parse(res.body)['data']['languages'][0...5].each do |language|
  hours = language['hours']
  mins = language['minutes']
  percent = language['percent'] / 100
  time_str = format_duration(hours, mins, opts[:format])
  lines.append "#{language['name'].ljust 11} #{time_str.ljust 14} #{make_bar(percent, 21)}"
end

if lines.empty?
  lines.append 'Nothing here.'
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
