s = 'Hello world'

def build_tree(s)
    a = s.chars.uniq.map {|c| {char: c, count: s.chars.count(c)}}.sort {|a, b| [b[:count], a[:char]] <=> [a[:count], b[:char]]}
    pq = a.map { |c| {char: c[:char], count: c[:count], left: nil, right: nil} }

    while pq.size > 1 do
        left, right = pq.pop(2)

        if left[:count] < right[:count]
            left, right = right, left
        end

        pq << {char: nil, count: left[:count] + right[:count], left: left, right: right}

        pq.sort! {|a,b| [b[:count], a[:char] || ''] <=> [a[:count], b[:char] || '']}
    end

    pq[0]
end

def build_table(tree)
    q = [{node: tree, code: ''}]

    codes = {}

    while q.size > 0 do
        e = q.shift

        if e[:node][:left].nil? && e[:node][:right].nil?
            codes[e[:node][:char]] = e[:code]
            next
        end

        q.push({node: e[:node][:left], code: e[:code] + '0'}) if !e[:node][:left].nil?

        q.push({node: e[:node][:right], code: e[:code] + '1'}) if !e[:node][:right].nil?
    end

    codes
end

def encode(s)
    tree = build_tree(s)
    codes = build_table(tree)
    s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join
end

def decode(s, tree)
    s1 = s.chars.map {|c| c.ord.to_s(2).rjust(8, '0')}.join
    puts s1
end

s = 'Hello world'
tree = build_tree(s)
codes = build_table(tree)
encoded = encode(s)

puts "Codes: #{codes.inspect}"
puts "Encoded (chars):  #{s.chars.map {|c| c.ljust(codes[c].length, ' ')}.join(' ')}"
puts "Encoded (each):   #{s.chars.map {|c| codes[c]}.join(' ')}"
puts "Encoded (bytes):  " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| slice.join}.join(' ')
puts "Encoded (hex):    " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| "0x#{slice.join.to_i(2).to_s(16).rjust(2, '0').upcase}".ljust(8, ' ')}.join(' ')
puts "Encoded (bin):    " + s.chars.map {|c| codes[c]}.join
puts "Encoded (raw):    #{encoded}"

decoded = decode(encoded, tree)
puts "Decoded: #{decoded}"

# bin 10100110101111000001110000010010
# enc 10100110101111000001110000010010