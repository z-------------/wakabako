#!/usr/bin/env ruby

require 'base64'
require 'gist'
require 'json'
require 'net/http'
require_relative 'helpers.rb'

### consts ###

BASE = 'https://wakatime.com/api/v1'

BAR_SCHEMES = [
    ['░', '▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
    [' ', '▏', '▎', '▍', '▌', '▋', '▊', '▉', '█'],
]

### parse options ###

opts = {
    dry: false,
    format: :long,
    fractional: false,
    help: false,
    'include-percent': false,
    'relative-bars': false,
    scheme: 0,
    width: 21,
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
        if opts[key].class.equal? Integer
            val = val_str.to_i
        else
            val = val_str.to_sym
        end
    end

    opts[key] = val
end

### main ###

if opts[:help]
    puts <<-END
Options:
  --help            Print this help and exit.                       [boolean] [default=false]
  --dry             Print to stdout instead of uploading a gist.    [boolean] [default=false]
  --format=FORMAT   Control duration format. FORMAT can be `short'
                    or `long'.                                       [string] [default=long]
  --fractional      Use partially-filled block element characters.  [boolean] [default=false]
  --include-percent Include a percentage after each bar.            [boolean] [default=false]
  --relative-bars   Scale bars relative to the most used language
                    instead of the sum of all languages used.       [boolean] [default=false]
  --scheme=SCHEME   Which set of block element characters to use.
                    SCHEME can be 0 or 1.                           [integer] [default=0]
  --width=WIDTH     The number of characters to use for each bar.   [integer] [default=21]
    END
    exit
end

begin
    config = read_config("#{__dir__}/config.txt")
rescue Errno::ENOENT
    begin
        config = read_config("#{__dir__}/config.toml")
    rescue Errno::ENOENT
        seppuku 'No config file found. Exiting.'
    end
end
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

    perc = percent / 100
    if opts[:'relative-bars']
        if i == 0
            $percent_max = percent
            perc = 1.0
        else
            perc = percent / $percent_max
        end
    end
    bar = make_bar(perc, opts[:width], opts[:scheme], opts[:fractional])

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
