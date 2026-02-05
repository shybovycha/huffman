class TreeNode
  getter char : UInt8 | Nil
  getter count : Int32
  getter left : TreeNode | Nil
  getter right : TreeNode | Nil

  def initialize(@char : UInt8 | Nil, @count : Int32, @left : TreeNode | Nil, @right : TreeNode | Nil)
  end
end

class SimpleDeflate
  def encode(message : String) : String
    encoded = encode_impl(message)
    length_bytes = Bytes.new(4)
    length_bytes[0] = ((encoded[:length] >> 24) & 0xFF).to_u8
    length_bytes[1] = ((encoded[:length] >> 16) & 0xFF).to_u8
    length_bytes[2] = ((encoded[:length] >> 8) & 0xFF).to_u8
    length_bytes[3] = (encoded[:length] & 0xFF).to_u8
    all_bytes = length_bytes.to_a + encoded[:header1] + encoded[:header2] + encoded[:body]
    String.new(Bytes.new(all_bytes.to_unsafe, all_bytes.size))
  end

  def decode(message : String) : String
    decode_impl(message)
  end

  private def build_tree(chars : Array(UInt8)) : TreeNode
    chars_with_counts = chars.uniq.map {|c| {char: c, count: chars.count(c)}}.sort {|a, b| [b[:count], a[:char]] <=> [a[:count], b[:char]]}
    pq = chars_with_counts.map {|c| TreeNode.new(c[:char], c[:count], nil, nil)}

    while pq.size > 1
      right = pq.pop
      left = pq.pop

      if left.count < right.count
        left, right = right, left
      end

      pq << TreeNode.new(nil, left.count + right.count, left, right)
      pq.sort! {|a, b| [b.count, a.char || 0] <=> [a.count, b.char || 0]}
    end

    pq.first
  end

  private def build_table(tree : TreeNode) : Hash(UInt8, String)
    q = [{node: tree.as(TreeNode | Nil), code: ""}]
    codes = {} of UInt8 => String

    while q.size > 0
      e = q.shift
      node = e[:node]

      next if node.nil?

      if node.left.nil? && node.right.nil?
        char = node.char
        codes[char] = e[:code] if char
        next
      end

      q.push({node: node.left, code: e[:code] + "0"}) if node.left
      q.push({node: node.right, code: e[:code] + "1"}) if node.right
    end

    codes
  end

  private def build_canonical_table(codes : Hash(UInt8, String)) : Hash(UInt8, String)
    sorted_codes = codes.to_a.sort_by {|k, v| [v.size, k]}
    canonical_codes = {} of UInt8 => String
    curr_code = 0
    prev_length = 0

    sorted_codes.each do |char, old_code|
      curr_code <<= (old_code.size - prev_length)
      canonical_codes[char] = curr_code.to_s(2).rjust(old_code.size, '0')
      curr_code += 1
      prev_length = old_code.size
    end

    canonical_codes
  end

  private def running_codes_lengths(codes : Hash(UInt8, String)) : Array(Int32 | Tuple(Int32, Int32))
    codes_lengths = (0..255).map {|i| (codes[i.to_u8]? || "").size}.to_a
    result = [] of (Int32 | Tuple(Int32, Int32))
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
            diff = [run_length, 138].min
            result << {18, diff - 11}
            run_length -= diff
          elsif run_length >= 3
            diff = [run_length, 10].min
            result << {17, diff - 3}
            run_length -= diff
          else
            run_length.times { result << 0 }
            run_length = 0
          end
        end
      elsif len != 0 && run_length >= 3
        result << len
        run_length -= 1

        while run_length >= 3
          diff = [run_length, 6].min
          result << {16, diff - 3}
          run_length -= diff
        end
      end

      run_length.times { result << len }
    end

    result
  end

  private def recreate_huffman_codes(code_lengths : Array(Int32)) : Array(String?)
    symbols_with_lengths = code_lengths.each_with_index.to_a.select {|len, _| len > 0}.map {|len, s| {s, len}}.sort_by {|pair| [pair[1], pair[0]]}
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

  private def encode_impl(s : String) : NamedTuple(header1: Array(UInt8), header2: Array(UInt8), body: Array(UInt8), length: Int32)
    bytes = s.bytes
    tree = build_tree(bytes)
    codes = build_table(tree)
    canonical_codes = build_canonical_table(codes)

    codes_lengths = running_codes_lengths(canonical_codes)
    raw_codes_lengths = codes_lengths.map {|i| i.is_a?(Tuple) ? i[0].to_u8 : i.to_u8}

    codes_lengths_tree = build_tree(raw_codes_lengths)
    codes_lengths_codes = build_table(codes_lengths_tree)
    canonical_codes_lengths = build_canonical_table(codes_lengths_codes)

    body_bits = bytes.map {|c| canonical_codes[c]}.join
    padded_body_bits = body_bits.ljust((body_bits.size + 7) // 8 * 8, '0')
    encoded_body = padded_body_bits.chars.each_slice(8).map {|slice| slice.join.to_i(2).to_u8}.to_a

    encoded_codes_lengths = codes_lengths.map do |c|
      if c.is_a?(Tuple)
        code, extra = c
        extra_bits = case code
          when 16 then 2
          when 17 then 3
          when 18 then 7
          else 0
        end
        canonical_codes_lengths[code.to_u8] + extra.to_s(2).rjust(extra_bits, '0')
      else
        canonical_codes_lengths[c.to_u8]
      end
    end.join

    bit_string = (0..18).map {|c| (canonical_codes_lengths[c.to_u8]? || "").size.to_s(2).rjust(3, '0')}.join
    padded_bit_string = bit_string.ljust((bit_string.size + 7) // 8 * 8, '0')
    encoded_codes_lengths_tree = padded_bit_string.chars.each_slice(8).map {|slice| slice.join.to_i(2).to_u8}.to_a

    padded_encoded_codes_lengths = encoded_codes_lengths.ljust((encoded_codes_lengths.size + 7) // 8 * 8, '0')
    encoded_codes_lengths_body = padded_encoded_codes_lengths.chars.each_slice(8).map {|slice| slice.join.to_i(2).to_u8}.to_a

    {
      header1: encoded_codes_lengths_tree,
      header2: encoded_codes_lengths_body,
      body: encoded_body,
      length: bytes.size
    }
  end

  private def decode_code_lengths_lengths(header : Bytes) : Array(Int32)
    bits = header.map {|ch| ch.to_s(2).rjust(8, '0')}.join
    code_lengths = Array(Int32).new(19, 0)

    (0..18).each do |e|
      start_bit = e * 3
      three_bits = bits[start_bit, 3]
      length = three_bits.to_i(2)
      code_lengths[e] = length
    end

    code_lengths
  end

  private def decode_codes_lengths_with_position(header : Bytes, codes_lengths_tree : Array(String?)) : Tuple(Array(Int32), Int32)
    bits = header.map {|b| b.to_s(2).rjust(8, '0')}.join
    tree_inv = {} of String => Int32
    codes_lengths_tree.each_with_index do |code, idx|
      tree_inv[code] = idx if code
    end

    bit_pos = 0
    buf = ""
    res = [] of Int32

    while bit_pos < bits.size && res.size < 256
      buf += bits[bit_pos]
      bit_pos += 1

      if tree_inv.has_key?(buf)
        symbol = tree_inv[buf]
        buf = ""

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

    {res, bit_pos}
  end

  private def decode_body(body : Bytes, codes_lengths : Array(String?), length : Int32) : String
    bits = body.map {|b| b.to_s(2).rjust(8, '0')}.join
    bytes = decode_with_tree(bits, codes_lengths, length)
    String.new(Bytes.new(bytes.to_unsafe, bytes.size))
  end

  private def decode_with_tree(bits : String, tree : Array(String?), max_symbols : Int32? = nil) : Array(UInt8)
    tree_inv = {} of String => Int32
    tree.each_with_index do |code, idx|
      tree_inv[code] = idx if code
    end

    res = [] of UInt8
    buf = ""

    bits.each_char do |bit|
      buf += bit

      if tree_inv.has_key?(buf)
        res << tree_inv[buf].to_u8
        buf = ""
        break if max_symbols && res.size >= max_symbols
      end
    end

    res
  end

  private def decode_impl(message : String) : String
    bytes = message.bytes
    length = ((bytes[0].to_u32 << 24) | (bytes[1].to_u32 << 16) | (bytes[2].to_u32 << 8) | bytes[3].to_u32).to_i32
    header1 = Bytes.new(bytes[4..11].to_unsafe, 8)

    code_lengths_lengths = decode_code_lengths_lengths(header1)
    tree = recreate_huffman_codes(code_lengths_lengths)

    header2_start = Bytes.new(bytes[12..].to_unsafe, bytes.size - 12)
    codes_lengths, pos = decode_codes_lengths_with_position(header2_start, tree)

    header2_length = (pos + 7) // 8
    body = Bytes.new(bytes[(12 + header2_length)..].to_unsafe, bytes.size - 12 - header2_length)
    codes = recreate_huffman_codes(codes_lengths)

    decode_body(body, codes, length)
  end
end

input = STDIN.gets_to_end
if ARGV[0] == "encode"
  puts SimpleDeflate.new.encode(STDIN.gets_to_end)
elsif ARGV[0] == "decode"
  puts SimpleDeflate.new.decode(STDIN.gets_to_end)
end

