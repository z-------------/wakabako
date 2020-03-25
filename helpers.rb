def seppuku msg
    STDERR.puts msg
    exit 1
end

def pluralize(n, s, c = 's')
    if n == 1 then s else s + c end
end

def make_bar(p, size, scheme = 0, fractional = false)
    chars = BAR_SCHEMES[scheme]
    count = (p * size)
    full = count.floor
    frac = count % 1
    (chars.last * full + ((fractional and frac > 0) ? chars[(chars.length * frac).round] : '')).ljust(size, chars.first)
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

def read_config(filename)
    config = {}
    data = File.open(filename).read
    data.gsub!(/\r\n?/, "\n") # normalize newlines
    data.each_line do |line|
        kv = line.split('=').map do |t| t.strip end
        next if kv.length != 2
        val = kv[1].gsub(/^"/, '').gsub(/"$/, '') # remove surrounding quotes
        config[kv[0]] = val
    end
    config
end
