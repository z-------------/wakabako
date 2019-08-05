#!/usr/bin/env ruby

require 'base64'
require 'json'
require 'net/http'
require 'toml'

BASE = 'https://wakatime.com/api/v1'

BAR_EMPTY = '░'
BAR_FULL = '█'

def pluralize(n, s, c = 's')
  if n == 1 then s else s + c end
end

def make_bar(p, size)
  (BAR_FULL * (p * size).round).ljust(size, BAR_EMPTY)
end

config = TOML.load_file("#{__dir__}/config.toml")
auth_key_hashed = Base64.encode64(config['auth_key']).chomp

uri = URI("#{BASE}/users/#{config['user']}/stats/last_7_days")
req = Net::HTTP::Get.new(uri)
req['Authorization'] = "Basic #{auth_key_hashed}"

res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) { |http|
  http.request(req)
}

formatted = []

JSON.parse(res.body)["data"]["languages"][0...5].each { |language|
  hours = language["hours"]
  mins = language["minutes"]
  percent = language["percent"] / 100
  time_str = "#{hours} #{pluralize(hours, 'hr')} #{mins} #{pluralize(mins, 'min')}"
  formatted.append "#{language["name"].ljust 11} #{time_str.ljust 14} #{make_bar(percent, 21)}"
}

if formatted.empty?
  formatted.append 'Nothing here.'
end

File.open('gist.txt', 'w') { |file| file.puts formatted }

cmd = "gist -u #{config['gist_id']} -f \"#{config['title']}\" gist.txt"
system cmd
