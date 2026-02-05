# old
class TreeNode
    getter char : UInt8 | Nil
    getter count : Int32
    getter left : TreeNode | Nil
    getter right : TreeNode | Nil

    def initialize(char : UInt8 | Nil, count : Int32, left : TreeNode | Nil, right : TreeNode | Nil)
        @char = char
        @count = count
        @left = left
        @right = right
    end
end

class SimpleDHT
    def encode(message : String) : String
      encoded = encode_impl(message)
      all_bytes = encoded[:header1] + encoded[:header2] + encoded[:body]
      String.new(Bytes.new(all_bytes.to_unsafe, all_bytes.size))
    end

    def decode(message : String) : String
      decode_impl(message)
    end

    private def build_tree(chars : Array(UInt8)) : TreeNode
        chars_with_counts = chars.uniq.map {|c| { char: c, count: chars.count(c) }}.sort {|a, b| [b[:count], a[:char]] <=> [a[:count], b[:char]]}
        pq = chars_with_counts.map { |c| TreeNode.new(c[:char], c[:count], nil, nil) }

        while pq.size > 1
            left, right = pq.pop(2)

            if left.count < right.count
                left, right = right, left
            end

            pq << TreeNode.new(nil, left.count + right.count, left, right)

            pq.sort! {|a,b| [b.count, a.char || 0] <=> [a.count, b.char || 0]}
        end

        pq[0]
    end

    private def build_table(tree) : Hash(UInt8, String)
        q = [{ node: tree, code: "" }] of NamedTuple(node: TreeNode | Nil, code: String)

        codes = {} of UInt8 => String

        while q.size > 0
            e = q.shift
            node, code = e[:node], e[:code]

            next if node.nil?

            char = node.char
            left, right = node.left, node.right

            if left.nil? && right.nil?
                if char
                    codes[char] = e[:code]
                    next
                end
            end

            q.push({node: left, code: code + "0"}) if left
            q.push({node: right, code: code + "1"}) if right
        end

        codes
    end

    private def build_canonical_table(codes : Hash(UInt8, String)) : Hash(UInt8, String)
        codes = codes.to_a.sort_by {|k, v| [v.size, k]}
        canonical_codes = {} of UInt8 => String
        curr_code = 0
        prev_length = 0

        codes.each do |char, old_code|
            curr_code <<= (old_code.size - prev_length)
            canonical_codes[char] = curr_code.to_s(2).rjust(old_code.size, '0')
            curr_code += 1
            prev_length = old_code.size
        end

        canonical_codes
    end

    private def build_canonical_codes(message : String) : Hash(UInt8, String)
      build_canonical_table(build_table(build_tree(message.bytes)))
    end

    private def encode_impl(message : String) : NamedTuple(header1: Array(UInt8), header2: Array(UInt8), body: Array(UInt8))
      codes = build_canonical_codes(message)
      grouped_codes = codes.values.group_by { |code| code.size }

      codes_count_by_length = grouped_codes.transform_values { |cs| cs.size }

      header1 = (1..15).map { |len| codes_count_by_length[len]? || 0 }.map {|c| c.to_u8}.to_a
      header2 = codes.keys.to_a #map {|c| c.to_u8}
      body = message.bytes.map { |byte| codes[byte] }.join.chars.each_slice(8).map { |slice| slice.join.ljust(8, '0').to_i(2).to_u8 }.to_a

      { header1: (header1), header2: (header2), body: (body) }
    end

    private def recreate_huffman_codes(code_lengths : Array(Int32))
        symbols_with_lengths = code_lengths.each_with_index.to_a.select {|len, _| len > 0}.map {|len, s| {s, len} }.sort_by {|pair| [pair[1], pair[0]]}

        res = Array(String?).new(code_lengths.size, nil)
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

    private def decode_with_table(bits : String, table : Hash(String, UInt8)) : Bytes
        res = [] of UInt8
        buf = ""

        bits.each_char do |bit|
            buf += bit

            if table.has_key? buf
                res << table[buf]
                buf = ""
            end
        end

        Bytes.new(res.to_unsafe, res.size)
    end

    private def decode_impl(message : String) : String
      bytes = message.bytes
      counts_encoded = bytes[0,15]

      counts = counts_encoded.each_with_index.flat_map {|n,len| Array.new(n, len+1)}.to_a
      codes = recreate_huffman_codes(counts).compact

      symbols = bytes[15, codes.size]
      body_encoded = bytes[15 + codes.size ..]
      body_bits = body_encoded.map {|b| b.to_s(2).rjust(8, '0')}.join

      table = codes.zip(symbols).to_h
      new_bytes = decode_with_table(body_bits, table)

      String.new(new_bytes)
    end
end

if ARGV.size != 1 || (ARGV[0] != "encode" && ARGV[0] != "decode")
  STDERR.puts "Usage: #{PROGRAM_NAME} encode|decode < input > output"
  exit 1
end

input = STDIN.gets_to_end
output = ARGV[0] == "encode" ? SimpleDHT.new.encode(input) : SimpleDHT.new.decode(input)
STDOUT.print(output)
