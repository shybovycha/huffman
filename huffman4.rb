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
                    diff = [138, run_length].min
                    result << [18, diff - 11]
                    run_length -= diff
                elsif run_length >= 3
                    # code 17, repeat '0' 3..10 times
                    diff = [10, run_length].min
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
                diff = [6, run_length].min
                result << [16, diff - 3]
                run_length -= diff
            end
        end

        run_length.times { result << len }
    end

    result
end

def encode(s)
    tree = build_tree(s.bytes)
    codes = build_table(tree)
    canonical_codes = build_canonical_table(codes)

    codes_lengths = running_codes_lengths(canonical_codes)
    raw_codes_lengths = codes_lengths.map {|i| if i.is_a?(Array) then i[0] else i end}

    codes_lengths_tree = build_tree(raw_codes_lengths)
    codes_lengths_codes = build_table(codes_lengths_tree)
    canonical_codes_lengths = build_canonical_table(codes_lengths_codes)

    body_bits = s.bytes.map {|c| canonical_codes[c]}.join
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
    padded_bit_string = bit_string.ljust((bit_string.length + 7) / 8 * 8, '0')  # Pad to multiple of 8
    encoded_codes_lengths_tree = padded_bit_string.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join

    padded_encoded_codes_lengths = encoded_codes_lengths.ljust((encoded_codes_lengths.length + 7) / 8 * 8, '0')
    encoded_codes_lengths_body = padded_encoded_codes_lengths.chars.each_slice(8).map {|slice| slice.join.to_i(2).chr}.join

    # puts ">> canonical codes: #{canonical_codes.inspect}\n\n"
    # puts ">> codes_lengths: #{codes_lengths.inspect}\n\n"
    # puts ">> raw codes_lengths: #{raw_codes_lengths.inspect}\n\n"
    # puts ">> codes_lengths_tree: #{codes_lengths_tree.inspect}\n\n"
    # puts ">> codes_lengths_codes: #{codes_lengths_codes.inspect}\n\n"
    # puts ">> canonical code lengths: #{canonical_codes_lengths.inspect}\n\n"
    # puts ">> encoded codes_lengths: #{encoded_codes_lengths.inspect}\n\n"
    # puts ">> encoded codes_lengths_tree: #{encoded_codes_lengths_tree.inspect}\n\n"
    # puts ">> encoded codes_lengths_body: #{encoded_codes_lengths_body}\n\n"
    # puts ">> encoded body: #{encoded_body.inspect}\n\n"

    {
        header1: encoded_codes_lengths_tree,
        header2: encoded_codes_lengths_body,
        body: encoded_body
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

def decode_running_lengths(compressed_code_lengths)
    res = []

    compressed_code_lengths.each do |e|
        if e.is_a?(Array)
            code, extras = e

            case code
            when 16
                repeats = 3 + extras
                repeats.times { res << res.last }

            when 17
                repeats = 3 + extras
                repeats.times { res << 0 }

            when 18
                repeats = 11 + extras
                repeats.times { res << 0 }
            end
        else
            res << e
        end
    end

    res << 0 while res.length < 256

    res
end

def decode_compressed_code_lengths(bits, codes_lengths_tree)
    tree_inv = codes_lengths_tree.each_with_index.to_h

    compressed_code_lengths = []
    bit_pos = 0
    buf = ''
    decoded_count = 0

    while bit_pos < bits.length && decoded_count < 256
        buf += bits[bit_pos]
        bit_pos += 1

        if tree_inv.key?(buf)
            symbol = tree_inv[buf]
            buf = ''

            case symbol
            when 16
                extra_bits = bits[bit_pos, 2].to_i(2)
                bit_pos += 2
                compressed_code_lengths << [16, extra_bits]
                decoded_count += 3 + extra_bits # code 16 repeats 3-6 repetitions
            when 17
                extra_bits = bits[bit_pos, 3].to_i(2)
                bit_pos += 3
                compressed_code_lengths << [17, extra_bits]
                decoded_count += 3 + extra_bits # code 17 repeats 3-10 repetitions
            when 18
                extra_bits = bits[bit_pos, 7].to_i(2)
                bit_pos += 7
                compressed_code_lengths << [18, extra_bits]
                decoded_count += 11 + extra_bits # code 18 repeats 11-138 repetitions
            else
                compressed_code_lengths << symbol
                decoded_count += 1 # any other code adds 1 instance of itself
            end
        end
    end

    compressed_code_lengths
end

def decode_codes_lengths(header, codes_lengths_tree)
    bits = header.bytes.map {|b| b.to_s(2).rjust(8, '0')}.join
    compressed_code_lengths = decode_compressed_code_lengths(bits, codes_lengths_tree)
    decode_running_lengths(compressed_code_lengths)
end

def decode_body(body, codes_lengths)
    bits = body.bytes.map {|b| b.to_s(2).rjust(8, '0')}.join
    bytes = decode_with_tree(bits, codes_lengths)
    bytes.pack('C*').force_encoding('UTF-8')
end

def decode_with_tree(bits, tree)
    tree_inv = tree.each_with_index.to_h

    res = []
    buf = ''

    bits.each_char do |bit|
        buf += bit

        if tree_inv.key? buf
            res << tree_inv[buf]
            buf = ''
        end
    end

    res
end

def decode(header1, header2, body)
    code_lengths_lengths = decode_code_lengths_lengths(header1)
    tree = recreate_huffman_codes(code_lengths_lengths)
    codes_lengths = decode_codes_lengths(header2, tree)

    codes = recreate_huffman_codes(codes_lengths)
    decode_body(body, codes)
end

s = <<-EOL
In 2026, the gap between local open-source models and cloud-based giants has narrowed significantly. For coding specifically, a few "heavy hitters" dominate the scene depending on your hardware.

Here are the best free/open-source LLM models for local coding, categorized by their performance and resource requirements.

---

## 1. The Heavy Hitters (SOTA Performance)

These models rival GPT-4o and Claude 3.5 Sonnet in logic and code generation.

* **Qwen3-Coder (30B or 480B MoE):** Alibaba's late 2025 release is widely considered the king of open-source coding. The **30B** variant is the "sweet spot" for high-end consumer GPUs, while the **480B (Mixture of Experts)** is an agentic powerhouse that can handle entire repository refactors if you have the VRAM.
* **DeepSeek-Coder V3:** A massive Mixture-of-Experts (MoE) model that excels at "thinking" through complex logic. It is particularly strong in Python, C++, and Rust. Its reasoning capabilities make it excellent for debugging deep-seated architectural bugs.
* **GPT-OSS (120B):** OpenAI’s open-weight model series (released late 2025). It brings the "GPT feel"—polished instruction following and high reliability—to the local ecosystem.

---

## 2. Recommended Models by Hardware

Your choice depends entirely on how much RAM/VRAM you have available.

### **Entry-Level (8GB - 16GB RAM)**

*Best for: Laptops, autocomplete, and simple script generation.*

* **Llama 4 Scout (17B MoE):** Meta's latest "small" model. Extremely fast and surprisingly smart for its size.
* **Qwen 2.5 Coder (7B):** Still a reliable favorite for its speed-to-accuracy ratio.
* **Gemma 3 (4B/12B):** Google's lightweight models are highly optimized for edge devices and perform exceptionally well on standard MacBook Airs or high-end Windows laptops.

### **Mid-Range (32GB - 64GB RAM)**

*Best for: Professional daily-driver assistants.*

* **Qwen2.5 Coder (32B):** Often cited as the best "pound-for-pound" model. It fits in 32GB of RAM with 4-bit quantization and handles complex multi-file logic with ease.
* **GPT-OSS (20B):** Optimized for low latency; it feels snappy and is very good at following strict formatting (like JSON or specific boilerplate).

### **High-End (64GB+ RAM or Multi-GPU)**

*Best for: Complex architectural work and agentic coding.*

* **DeepSeek V3 / V3.2:** Large MoE models that require significant resources but provide near-perfect code generation.
* **Qwen3-Coder (480B):** For those running Mac Studio (M2/M3 Ultra) or multi-RTX 4090/5090 setups.

---

## 3. Comparison Table: Coding Performance

| Model Family | Best For... | Minimum VRAM (Quantized) | Coding Benchmark (HumanEval) |
| --- | --- | --- | --- |
| **Qwen3-Coder 30B** | All-around Professional | 20GB - 24GB | ~92% |
| **DeepSeek V3** | Complex Logic/Reasoning | 48GB+ (MoE) | ~90% |
| **Llama 4 Scout** | Speed & Chat | 10GB - 12GB | ~85% |
| **GPT-OSS 20B** | Tool Use & API logic | 12GB - 16GB | ~88% |
| **Gemma 3 12B** | Low-resource / Laptops | 8GB - 10GB | ~82% |

---

## 4. How to Run Them Locally

To get these running, you generally don't need to be a DevOps expert. Use one of these three tools:

1. **Ollama (CLI-focused):** The most popular choice. Just run `ollama run qwen2.5-coder:32b` to start. It handles the backend and optimization automatically.
2. **LM Studio (GUI-focused):** Perfect if you prefer a visual interface. It lets you search for models on Hugging Face and download the specific "Quantized" (compressed) versions that fit your RAM.
3. **Continue.dev (IDE Integration):** This is a VS Code / JetBrains extension that allows you to plug these local models directly into your editor, replacing GitHub Copilot with your local instance.

> [!TIP]
> **What is "Quantization"?**
> You will often see tags like **Q4_K_M** or **Q8_0**. This refers to how much the model has been compressed. For coding, try to stay at **Q4** or higher; anything lower (like Q2) tends to lose the "logic" required for syntax-perfect code.
EOL

encoded = encode(s)
decoded = decode(encoded[:header1], encoded[:header2], encoded[:body])

# puts "Codes: #{codes.inspect}\n\n"
# puts "Code lengths: #{code_lengths.inspect}\n\n"
# puts "Encoded (chars):  #{s.chars.map {|c| c.ljust(codes[c].length, ' ')}.join(' ')}"
# puts "Encoded (each):   #{s.chars.map {|c| codes[c]}.join(' ')}"
# puts "Encoded (bytes):  " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| slice.join}.join(' ')
# puts "Encoded (hex):    " + s.chars.map {|c| codes[c]}.join.chars.each_slice(8).map {|slice| "0x#{slice.join.to_i(2).to_s(16).rjust(2, '0').upcase}".ljust(8, ' ')}.join(' ')
# puts "Encoded (bin):    " + s.chars.map {|c| codes[c]}.join
puts "Encoded (raw): #{encoded.inspect}\n\n\n"
puts "Decoded: #{decoded}\n\n\n"
puts "Source length: #{s.length}\n"
puts "Encoded length: #{encoded[:body].length + encoded[:header1].length + encoded[:header2].length}"
puts "> encoded length: #{encoded[:body].length}"
puts "> header length: #{encoded[:header1].length + encoded[:header2].length}"
puts ">> header1 length: #{encoded[:header1].length}"
puts ">> header2 length: #{encoded[:header2].length}"
puts "Compression rate: #{(((s.length / (encoded[:body].length + encoded[:header1].length + encoded[:header2].length).to_f) - 1.0) * 100).to_i}%"

