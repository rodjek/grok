# This bit of code has been shamelessly stolen from rufus-scheduler because
# it's awesome.

module Grok
  def Grok.parse_time_string(string)
    string = string.strip
    index = -1
    result = 0.0

    number = ''
    loop do
      index = index+1

      if index >= string.length
        result += (Float(number) / 1000.0) if number.length > 0
        break
      end

      c = string[index, 1]

      if (c >= '0' and c <= '9')
        number += c
        next
      end

      value = Integer(number)
      number = ''
      multiplier = DURATIONS[c]

      raise "unknown time char '#{c}'" unless multiplier

      result += (value * multiplier)
    end

    result
  end

protected

  DURATIONS2M = [
    [ 'y', 365 * 24 * 3600 ],
    [ 'M', 30 * 24 * 3600 ],
    [ 'w', 7 * 24 * 3600 ],
    [ 'd', 24 * 3600 ],
    [ 'h', 3600 ],
    [ 'm', 60 ],
    [ 's', 1 ]
  ]
    
  DURATIONS2 = DURATIONS2M.dup
  DURATIONS2.delete_at(1)

  DURATIONS = DURATIONS2M.inject({}) do |r, (k, v)|
    r[k] = v
    r
  end
end
