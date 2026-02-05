class SimpleDHT
  class << self
    def encode(message)
      encoded = encode_impl(message)
      [ :header1, :header2, :body ].map { |k| encoded[k].pack('C*').force_encoding('UTF-8') }.join
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

    def build_canonical_codes(message)
      build_canonical_table(build_table(build_tree(message.bytes)))
    end

    def encode_impl(message)
      codes = build_canonical_codes(message)
      grouped_codes = codes.values.group_by { |code| code.length }

      codes_count_by_length = grouped_codes.transform_values { |cs| cs.size }

      header1 = (1..15).map { |len| codes_count_by_length[len] || 0 }
      header2 = codes.keys # sort_by {|b,c| [c.length, b]}.map(&:first)
      body = message.bytes.map { |byte| codes[byte] }.join.chars.each_slice(8).map { |slice| slice.join.ljust(8, '0').to_i(2) }

      {
        header1: header1,
        header2: header2,
        body: body
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

    def decode_with_table(bits, table)
        res = []
        buf = ''

        bits.each_char do |bit|
            buf += bit

            if table.key? buf
                res << table[buf]
                buf = ''
            end
        end

        res
    end

    def decode_impl(message)
      bytes = message.bytes
      counts_encoded = bytes[0,15]

      counts = counts_encoded.each_with_index.map {|n,len| [len+1]*n}.flatten
      codes = recreate_huffman_codes(counts).compact

      symbols = bytes[15, codes.size]
      body_encoded = bytes[15 + codes.size ..]
      body_bits = body_encoded.map {|b| b.to_s(2).rjust(8, '0')}.join

      table = codes.zip(symbols).to_h
      new_bytes = decode_with_table(body_bits, table)

      new_bytes.pack('C*').force_encoding('UTF-8')
    end
  end
end
