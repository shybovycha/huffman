// SimpleDHT - Simplified DHT (Define Huffman Table) encoding
// Usage: simple_dht encode < input > output
//        simple_dht decode < input > output

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <memory>
#include <optional>
#include <sstream>

// ============================================================================
// Utility Functions
// ============================================================================

std::string to_binary(uint64_t n, size_t width) {
    std::string result;
    for (int i = width - 1; i >= 0; --i) {
        result += ((n >> i) & 1) ? '1' : '0';
    }
    return result;
}

std::string pad_left(std::string s, size_t width, char fill) {
    if (s.length() >= width) return s;
    return std::string(width - s.length(), fill) + s;
}

std::string pad_right(std::string s, size_t width, char fill) {
    if (s.length() >= width) return s;
    return s + std::string(width - s.length(), fill);
}

std::vector<uint8_t> string_to_bytes(const std::string& s) {
    return std::vector<uint8_t>(s.begin(), s.end());
}

std::string bytes_to_string(const std::vector<uint8_t>& bytes) {
    return std::string(bytes.begin(), bytes.end());
}

// ============================================================================
// Huffman Tree Node
// ============================================================================

struct TreeNode {
    std::optional<uint8_t> ch;
    int count;
    std::shared_ptr<TreeNode> left;
    std::shared_ptr<TreeNode> right;
    
    TreeNode(std::optional<uint8_t> c, int cnt) : ch(c), count(cnt), left(nullptr), right(nullptr) {}
};

// ============================================================================
// Huffman Functions
// ============================================================================

std::shared_ptr<TreeNode> build_tree(const std::vector<uint8_t>& chars) {
    std::map<uint8_t, int> freq;
    for (auto c : chars) freq[c]++;
    
    std::vector<std::shared_ptr<TreeNode>> pq;
    for (auto [c, count] : freq) {
        pq.push_back(std::make_shared<TreeNode>(c, count));
    }
    
    auto cmp = [](const std::shared_ptr<TreeNode>& a, const std::shared_ptr<TreeNode>& b) {
        if (a->count != b->count) return a->count > b->count;
        return (a->ch.value_or(0)) < (b->ch.value_or(0));
    };
    std::sort(pq.begin(), pq.end(), cmp);
    
    while (pq.size() > 1) {
        auto right = pq.back(); pq.pop_back();
        auto left = pq.back(); pq.pop_back();
        
        if (left->count < right->count) std::swap(left, right);
        
        auto parent = std::make_shared<TreeNode>(std::nullopt, left->count + right->count);
        parent->left = left;
        parent->right = right;
        
        pq.push_back(parent);
        std::sort(pq.begin(), pq.end(), cmp);
    }
    
    return pq[0];
}

std::map<uint8_t, std::string> build_table(std::shared_ptr<TreeNode> tree) {
    struct QueueItem { std::shared_ptr<TreeNode> node; std::string code; };
    std::vector<QueueItem> q = {{tree, ""}};
    std::map<uint8_t, std::string> codes;
    
    while (!q.empty()) {
        auto e = q.front();
        q.erase(q.begin());
        
        if (!e.node->left && !e.node->right) {
            codes[e.node->ch.value()] = e.code;
            continue;
        }
        
        if (e.node->left) q.push_back({e.node->left, e.code + "0"});
        if (e.node->right) q.push_back({e.node->right, e.code + "1"});
    }
    
    return codes;
}

std::map<uint8_t, std::string> build_canonical_table(const std::map<uint8_t, std::string>& codes) {
    std::vector<std::pair<uint8_t, std::string>> sorted_codes(codes.begin(), codes.end());
    std::sort(sorted_codes.begin(), sorted_codes.end(), [](auto& a, auto& b) {
        if (a.second.length() != b.second.length()) return a.second.length() < b.second.length();
        return a.first < b.first;
    });
    
    std::map<uint8_t, std::string> canonical_codes;
    uint64_t curr_code = 0;
    size_t prev_length = 0;
    
    for (auto [ch, old_code] : sorted_codes) {
        curr_code <<= (old_code.length() - prev_length);
        canonical_codes[ch] = pad_left(to_binary(curr_code, old_code.length()), old_code.length(), '0');
        curr_code += 1;
        prev_length = old_code.length();
    }
    
    return canonical_codes;
}

std::vector<std::optional<std::string>> recreate_huffman_codes(const std::vector<int>& code_lengths) {
    std::vector<std::pair<int, int>> symbols_with_lengths;
    for (int i = 0; i < code_lengths.size(); ++i) {
        if (code_lengths[i] > 0) {
            symbols_with_lengths.push_back({i, code_lengths[i]});
        }
    }

    std::sort(symbols_with_lengths.begin(), symbols_with_lengths.end(), [](auto& a, auto& b) {
        if (a.second != b.second) return a.second < b.second;
        return a.first < b.first;
    });

    std::vector<std::optional<std::string>> res(code_lengths.size());
    int prev_length = 0;
    uint64_t code = 0;

    for (auto [s, len] : symbols_with_lengths) {
        code <<= (len - prev_length);
        res[s] = pad_left(to_binary(code, len), len, '0');
        code += 1;
        prev_length = len;
    }

    return res;
}

// ============================================================================
// SimpleDHT Implementation
// ============================================================================

std::map<uint8_t, std::string> build_canonical_codes(const std::string& message) {
    auto bytes = string_to_bytes(message);
    auto tree = build_tree(bytes);
    auto codes = build_table(tree);
    return build_canonical_table(codes);
}

std::string encode(const std::string& message) {
    auto codes = build_canonical_codes(message);

    // Group codes by length
    std::map<size_t, int> codes_count_by_length;
    for (auto [ch, code] : codes) {
        codes_count_by_length[code.length()]++;
    }

    // header1: counts for each length 1-15
    std::vector<int> header1;
    for (int len = 1; len <= 15; ++len) {
        header1.push_back(codes_count_by_length[len]);
    }

    // header2: symbols in canonical order (sorted by code length, then by symbol)
    std::vector<std::pair<uint8_t, std::string>> sorted_codes(codes.begin(), codes.end());
    std::sort(sorted_codes.begin(), sorted_codes.end(), [](auto& a, auto& b) {
        if (a.second.length() != b.second.length()) return a.second.length() < b.second.length();
        return a.first < b.first;
    });

    std::vector<uint8_t> header2;
    for (auto [ch, code] : sorted_codes) {
        header2.push_back(ch);
    }

    // body: encode message bytes using Huffman codes
    std::string body_bits;
    for (auto byte : string_to_bytes(message)) {
        body_bits += codes[byte];
    }

    // Pad to byte boundary (pad RIGHT)
    body_bits = pad_right(body_bits, ((body_bits.length() + 7) / 8) * 8, '0');

    // Convert bits to bytes
    std::vector<uint8_t> body;
    for (size_t i = 0; i < body_bits.length(); i += 8) {
        uint8_t byte = 0;
        for (int j = 0; j < 8; ++j) {
            byte = (byte << 1) | (body_bits[i + j] - '0');
        }
        body.push_back(byte);
    }

    // Pack result: [4 bytes: length] + header1 + header2 + body
    std::string result;

    // Pack length as big-endian 32-bit
    uint32_t length = message.length();
    result += static_cast<char>((length >> 24) & 0xFF);
    result += static_cast<char>((length >> 16) & 0xFF);
    result += static_cast<char>((length >> 8) & 0xFF);
    result += static_cast<char>(length & 0xFF);

    for (auto count : header1) {
        result += static_cast<char>(count);
    }
    for (auto byte : header2) {
        result += static_cast<char>(byte);
    }
    for (auto byte : body) {
        result += static_cast<char>(byte);
    }

    return result;
}

std::string decode(const std::string& message) {
    auto bytes = string_to_bytes(message);

    // Extract length (first 4 bytes, big-endian)
    uint32_t length = (static_cast<uint32_t>(bytes[0]) << 24) |
                      (static_cast<uint32_t>(bytes[1]) << 16) |
                      (static_cast<uint32_t>(bytes[2]) << 8) |
                      static_cast<uint32_t>(bytes[3]);

    // Extract header1 (bytes 4-18, 15 bytes)
    std::vector<int> counts_encoded(bytes.begin() + 4, bytes.begin() + 19);

    // Recreate code lengths from counts
    std::vector<int> counts;
    for (int len = 0; len < counts_encoded.size(); ++len) {
        for (int i = 0; i < counts_encoded[len]; ++i) {
            counts.push_back(len + 1);
        }
    }

    auto codes = recreate_huffman_codes(counts);

    // Remove nullopt entries
    std::vector<std::string> codes_compact;
    for (auto& code : codes) {
        if (code.has_value()) codes_compact.push_back(code.value());
    }

    // Extract header2 (symbols)
    std::vector<uint8_t> symbols(bytes.begin() + 19, bytes.begin() + 19 + codes_compact.size());

    // Extract body
    std::vector<uint8_t> body_encoded(bytes.begin() + 19 + codes_compact.size(), bytes.end());

    // Convert body to bits
    std::string body_bits;
    for (auto b : body_encoded) {
        body_bits += pad_left(to_binary(b, 8), 8, '0');
    }

    // Create lookup table (code -> symbol)
    std::map<std::string, uint8_t> table;
    for (size_t i = 0; i < codes_compact.size(); ++i) {
        table[codes_compact[i]] = symbols[i];
    }

    // Decode body
    std::vector<uint8_t> res;
    std::string buf;

    for (char bit : body_bits) {
        buf += bit;

        if (table.count(buf)) {
            res.push_back(table.at(buf));
            buf.clear();

            // Stop when we've decoded the expected number of bytes
            if (res.size() >= length) {
                break;
            }
        }
    }

    return bytes_to_string(res);
}

// ============================================================================
// Main - CLI Interface
// ============================================================================

int main(int argc, char* argv[]) {
    if (argc != 2 || (std::string(argv[1]) != "encode" && std::string(argv[1]) != "decode")) {
        std::cerr << "Usage: " << argv[0] << " encode|decode < input > output\n";
        return 1;
    }

    // Read entire STDIN
    std::string input((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());

    std::string output;
    if (std::string(argv[1]) == "encode") {
        output = encode(input);
    } else {
        output = decode(input);
    }

    std::cout << output;
    return 0;
}

