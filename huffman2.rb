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

def build_canonical_table(codes)
    codes = codes.sort_by {|k, v| [v.length, k]}
    canonical_codes = {}
    curr_code = 0
    prev_length = 0

    codes.each do |char, old_code|
        curr_code <<= (old_code.length - prev_length)
        canonical_codes[char] = curr_code.to_s(2).rjust(old_code.length, '0')
        curr_code += 1
        prev_length = old_code.length
    end

    canonical_codes
end

def running_codes_lengths(codes)
    codes_lengths = (0..255).map {|i| (codes[i.chr] || '').length}

    result = []
    i = 0

    while i < codes_lengths.size
        len = codes_lengths[i]
        run_length = 1

        while i + run_length < codes_lengths.size && codes_lengths[i + run_length] == len
            run_length += 1
        end

        i += run_length

        if len == 0
            while run_length > 0
                if run_length >= 11
                    # code 18, repeat '0' 11..138 times
                    diff = [138, [11, run_length].max].min
                    result << [18, diff - 11]
                    run_length -= diff
                elsif run_length >= 3
                    # code 17, repeat '0' 3..10 times
                    diff = [10, [3, run_length].max].min
                    result << [17, diff - 3]
                    run_length -= diff
                else
                    result += [0] * run_length
                    run_length = 0
                end
            end
        elsif len != 0 && run_length >= 3
            result << len
            run_length -= 1

            while run_length > 0
                # code 16, repeat previous value 3..6 times
                diff = [6, [3, run_length].max].min
                result << [16, diff - 3]
                run_length -= diff
            end
        else
            run_length.times { result << len }
            run_length = 0
        end
    end

    result
end

def encode(s)
    tree = build_tree(s)
    codes = build_table(tree)
    canonical_codes = build_canonical_table(codes)
    encoded_body = s.chars.map {|c| canonical_codes[c]}.join.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join
end

def decode(s, tree)
    s1 = s.chars.map {|c| c.ord.to_s(2).rjust(8, '0')}.join
    puts s1
end

s = 'Hello world'
tree = build_tree(s)
codes = build_canonical_table(build_table(tree))
code_lengths = running_codes_lengths(codes)
encoded = encode(s)

puts "Codes: #{codes.inspect}"
puts "Code lengths: #{code_lengths.inspect}"
puts "Encoded (chars):  #{s.chars.map {|c| c.ljust(codes[c].length, ' ')}.join(' ')}"
puts "Encoded (each):   #{s.chars.map {|c| codes[c]}.join(' ')}"
puts "Encoded (bytes):  " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| slice.join}.join(' ')
puts "Encoded (hex):    " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| "0x#{slice.join.to_i(2).to_s(16).rjust(2, '0').upcase}".ljust(8, ' ')}.join(' ')
puts "Encoded (bin):    " + s.chars.map {|c| codes[c]}.join
puts "Encoded (raw):    #{encoded}"

decoded = decode(encoded, tree)
puts "Decoded: #{decoded}"

# bin 10111000101001001110001101011111
# enc 10111000101001001110001101011111