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
        canonical_codes[char] = curr_code.to_s(2).ljust(old_code.length, '0')
        curr_code += 1
        prev_length = old_code.length
    end

    canonical_codes
end

def build_canonical_codes(message)
  build_canonical_table(build_table(build_tree(message.bytes)))
end

def encode(message)
  codes = build_canonical_codes(message)
  grouped_codes = codes.values.group_by { |code| code.length }

  codes_count_by_length = grouped_codes.transform_values { |cs| cs.size }

  header1 = (1..15).map { |len| codes_count_by_length[len] || 0 }
  header2 = codes.keys
  body = message.bytes.map { |byte| codes[byte] }.join.chars.each_slice(8).map { |slice| slice.join.rjust(8, '0').to_i(2) }

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

def decode(message)
  bytes = message.bytes
  counts_encoded = bytes[0,15]

  counts = counts_encoded.each_with_index.map {|n,len| [len+1]*n}.flatten
  codes = recreate_huffman_codes counts

  symbols = bytes[15, codes.size]
  body_encoded = bytes[15 + codes.size ..]
  body_bits = body_encoded.map {|b| b.to_s(2).rjust(8, '0')}.join

  table = codes.zip(symbols).to_h
  new_bytes = decode_with_table(body_bits, table)

  new_bytes.pack('C*').force_encoding('UTF-8')
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
r1 = [ :header1, :header2, :body ].map { |k| encoded[k].pack('C*').force_encoding('UTF-8') }.join

puts "Original message: #{s.length}"
puts "Encoded message: #{r1.length}"
puts "> header1: #{encoded[:header1].length}"
puts "> header2: #{encoded[:header2].length}"
puts "> body: #{encoded[:body].length}"
puts "Compression ratio: #{(((s.length / (encoded[:body].length + encoded[:header1].length + encoded[:header2].length).to_f) - 1.0) * 100).to_i}%"
