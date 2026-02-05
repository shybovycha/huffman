class SimpleDeflate
  class << self
    def encode(message)
      encoded = encode_impl(message)
      [encoded[:length]].pack('N') + [ :header1, :header2, :body ].map { |k| encoded[k] }.join
    end

    def decode(message)
      decode_impl(message)
    end

    private

    def build_tree(chars)
        a = chars.uniq.map {|c| {char: c, count: chars.count(c)}}.sort {|a, b| [b[:count], a[:char]] <=> [a[:count], b[:char]]}
        pq = a.map { |c| {char: c[:char], count: c[:count], left: nil, right: nil} }

        while pq.size > 1
            left, right = pq.pop(2)

            if left[:count] < right[:count]
                left, right = right, left
            end

            pq << {char: nil, count: left[:count] + right[:count], left: left, right: right}

            pq.sort! {|a,b| [b[:count], a[:char] || 0] <=> [a[:count], b[:char] || 0]}
        end

        pq[0]
    end

    def build_table(tree)
        q = [{node: tree, code: ''}]

        codes = {}

        while q.size > 0
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
        codes_lengths = (0..255).map {|i| (codes[i] || '').length}

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
                        diff = [run_length, 138].min
                        result << [18, diff - 11]
                        run_length -= diff
                    elsif run_length >= 3
                        # code 17, repeat '0' 3..10 times
                        diff = [run_length, 10].min
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

                while run_length >= 3
                    # code 16, repeat previous value 3..6 times
                    diff = [run_length, 6].min
                    result << [16, diff - 3]
                    run_length -= diff
                end
            end

            run_length.times { result << len }
        end

        result
    end

    def encode_impl(s)
        bytes = s.bytes
        tree = build_tree(bytes)
        codes = build_table(tree)
        canonical_codes = build_canonical_table(codes)

        codes_lengths = running_codes_lengths(canonical_codes)
        raw_codes_lengths = codes_lengths.map {|i| if i.is_a?(Array) then i[0] else i end}

        codes_lengths_tree = build_tree(raw_codes_lengths)
        codes_lengths_codes = build_table(codes_lengths_tree)
        canonical_codes_lengths = build_canonical_table(codes_lengths_codes)

        body_bits = bytes.map {|c| canonical_codes[c]}.join
        padded_body_bits = body_bits.ljust((body_bits.length + 7) / 8 * 8, '0')
        encoded_body = padded_body_bits.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join
        encoded_codes_lengths = codes_lengths.map do |c|
            if c.is_a?(Array)
                code, extra = c
                extra_bits = case code
                    when 16 then 2
                    when 17 then 3
                    when 18 then 7
                end
                canonical_codes_lengths[code] + extra.to_s(2).rjust(extra_bits, '0')
            else
                canonical_codes_lengths[c]
            end
        end.join

        bit_string = (0..18).map {|c| (canonical_codes_lengths[c] || '').length.to_s(2).rjust(3, '0') }.join
        padded_bit_string = bit_string.ljust((bit_string.length + 7) / 8 * 8, '0')
        encoded_codes_lengths_tree = padded_bit_string.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join

        padded_encoded_codes_lengths = encoded_codes_lengths.ljust((encoded_codes_lengths.length + 7) / 8 * 8, '0')
        encoded_codes_lengths_body = padded_encoded_codes_lengths.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join

        {
            header1: encoded_codes_lengths_tree,
            header2: encoded_codes_lengths_body,
            body: encoded_body,
            length: bytes.length
        }
    end

    def recreate_huffman_codes(code_lengths)
        symbols_with_lengths = code_lengths.each_with_index.filter {|len, _| len > 0}.map {|len, s| [s, len] }.sort_by {|s, len| [len, s]}

        res = Array.new(code_lengths.size)
        prev_length = 0
        code = 0

        symbols_with_lengths.each do |s, len|
            code <<= (len - prev_length)
            res[s] = code.to_s(2).rjust(len, '0')
            code += 1
            prev_length = len
        end

        res
    end

    def decode_code_lengths_lengths(header)
        bits = header.bytes.map {|ch| ch.to_s(2).rjust(8, '0')}.join

        code_lengths = []

        (0..18).each do |e|
            start_bit = e * 3
            three_bits = bits[start_bit, 3]
            length = three_bits.to_i(2)
            code_lengths[e] = length
        end

        code_lengths
    end

    def decode_codes_lengths_with_position(header, codes_lengths_tree)
        bits = header.bytes.map {|b| b.to_s(2).rjust(8, '0')}.join

        tree_inv = codes_lengths_tree.each_with_index.to_h

        bit_pos = 0
        buf = ''

        res = []

        while bit_pos < bits.length && res.size < 256
            buf += bits[bit_pos]
            bit_pos += 1

            if tree_inv.key?(buf)
                symbol = tree_inv[buf]
                buf = ''

                case symbol
                when 16
                    extra_bits = bits[bit_pos, 2].to_i(2)
                    bit_pos += 2
                    repeats = 3 + extra_bits
                    repeats.times { res << res.last }
                when 17
                    extra_bits = bits[bit_pos, 3].to_i(2)
                    bit_pos += 3
                    repeats = 3 + extra_bits
                    repeats.times { res << 0 }
                when 18
                    extra_bits = bits[bit_pos, 7].to_i(2)
                    bit_pos += 7
                    repeats = 11 + extra_bits
                    repeats.times { res << 0 }
                else
                    res << symbol
                end
            end
        end

        [ res, bit_pos ]
    end

    def decode_body(body, codes_lengths, length)
        bits = body.bytes.map {|b| b.to_s(2).rjust(8, '0')}.join
        bytes = decode_with_tree(bits, codes_lengths, length)
        bytes.pack('C*').force_encoding('UTF-8')
    end

    def decode_with_tree(bits, tree, max_symbols = nil)
        tree_inv = tree.each_with_index.to_h

        res = []
        buf = ''

        bits.each_char do |bit|
            buf += bit

            if tree_inv.key? buf
                res << tree_inv[buf]
                buf = ''

                break if max_symbols && res.length >= max_symbols
            end
        end

        res
    end

    def decode_impl(message)
      length = message[0..3].unpack1('N')
      header1 = message[4..11]

      code_lengths_lengths = decode_code_lengths_lengths(header1)
      tree = recreate_huffman_codes(code_lengths_lengths)

      header2_start = message[12..]
      codes_lengths, pos = decode_codes_lengths_with_position(header2_start, tree)

      header2_length = (pos + 7) / 8
      body = message[(12 + header2_length)..]
      codes = recreate_huffman_codes(codes_lengths)

      decode_body(body, codes, length)
    end
  end
end

if ARGV[0] == 'encode'
  STDOUT.print SimpleDeflate.encode(STDIN.read)
elsif ARGV[0] == 'decode'
  STDOUT.print SimpleDeflate.decode(STDIN.read)
end
