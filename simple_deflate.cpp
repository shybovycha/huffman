#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <memory>
#include <optional>

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

struct TreeNode {
    std::optional<uint8_t> ch;
    int count;
    std::shared_ptr<TreeNode> left;
    std::shared_ptr<TreeNode> right;
    
    TreeNode(std::optional<uint8_t> c, int cnt) : ch(c), count(cnt), left(nullptr), right(nullptr) {}
};

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

struct RLEItem {
    bool is_pair;
    int value;
    int extra;  // only used when is_pair == true

    RLEItem(int v) : is_pair(false), value(v), extra(0) {}
    RLEItem(int v, int e) : is_pair(true), value(v), extra(e) {}
};

std::vector<RLEItem> running_codes_lengths(const std::map<uint8_t, std::string>& codes) {
    // Create array of code lengths for bytes 0-255
    std::vector<int> codes_lengths(256, 0);
    for (auto [byte, code] : codes) {
        codes_lengths[byte] = code.length();
    }

    std::vector<RLEItem> result;
    size_t i = 0;

    while (i < codes_lengths.size()) {
        int len = codes_lengths[i];
        int run_length = 1;

        while (i + run_length < codes_lengths.size() && codes_lengths[i + run_length] == len) {
            run_length++;
        }

        i += run_length;

        if (len == 0) {
            while (run_length > 0) {
                if (run_length >= 11) {
                    int diff = std::min(run_length, 138);
                    result.push_back(RLEItem(18, diff - 11));
                    run_length -= diff;
                } else if (run_length >= 3) {
                    int diff = std::min(run_length, 10);
                    result.push_back(RLEItem(17, diff - 3));
                    run_length -= diff;
                } else {
                    for (int j = 0; j < run_length; ++j) result.push_back(RLEItem(0));
                    run_length = 0;
                }
            }
        } else if (len != 0 && run_length >= 3) {
            result.push_back(RLEItem(len));
            run_length -= 1;

            while (run_length >= 3) {
                int diff = std::min(run_length, 6);
                result.push_back(RLEItem(16, diff - 3));
                run_length -= diff;
            }
        }

        // Add any remaining values individually
        for (int j = 0; j < run_length; ++j) result.push_back(RLEItem(len));
    }

    return result;
}

std::string encode(const std::string& message) {
    auto bytes = string_to_bytes(message);
    auto tree = build_tree(bytes);
    auto codes = build_table(tree);
    auto canonical_codes = build_canonical_table(codes);

    auto codes_lengths = running_codes_lengths(canonical_codes);

    std::vector<uint8_t> raw_codes_lengths;
    for (auto& item : codes_lengths) {
        raw_codes_lengths.push_back(item.value);
    }

    auto codes_lengths_tree = build_tree(raw_codes_lengths);
    auto codes_lengths_codes = build_table(codes_lengths_tree);
    auto canonical_codes_lengths = build_canonical_table(codes_lengths_codes);

    std::string body_bits;
    for (auto c : bytes) {
        body_bits += canonical_codes[c];
    }
    body_bits = pad_right(body_bits, ((body_bits.length() + 7) / 8) * 8, '0');

    std::string encoded_body;
    for (size_t i = 0; i < body_bits.length(); i += 8) {
        uint8_t byte = 0;
        for (int j = 0; j < 8; ++j) {
            byte = (byte << 1) | (body_bits[i + j] - '0');
        }
        encoded_body += static_cast<char>(byte);
    }

    std::string encoded_codes_lengths;
    for (auto& c : codes_lengths) {
        if (c.is_pair) {
            int extra_bits = (c.value == 16) ? 2 : (c.value == 17) ? 3 : 7;
            encoded_codes_lengths += canonical_codes_lengths[c.value];
            encoded_codes_lengths += pad_left(to_binary(c.extra, extra_bits), extra_bits, '0');
        } else {
            encoded_codes_lengths += canonical_codes_lengths[c.value];
        }
    }

    std::string bit_string;
    for (int c = 0; c <= 18; ++c) {
        int len = canonical_codes_lengths.count(c) ? canonical_codes_lengths[c].length() : 0;
        bit_string += pad_left(to_binary(len, 3), 3, '0');
    }
    bit_string = pad_right(bit_string, ((bit_string.length() + 7) / 8) * 8, '0');

    std::string encoded_codes_lengths_tree;
    for (size_t i = 0; i < bit_string.length(); i += 8) {
        uint8_t byte = 0;
        for (int j = 0; j < 8; ++j) {
            byte = (byte << 1) | (bit_string[i + j] - '0');
        }
        encoded_codes_lengths_tree += static_cast<char>(byte);
    }

    encoded_codes_lengths = pad_right(encoded_codes_lengths, ((encoded_codes_lengths.length() + 7) / 8) * 8, '0');

    std::string encoded_codes_lengths_body;
    for (size_t i = 0; i < encoded_codes_lengths.length(); i += 8) {
        uint8_t byte = 0;
        for (int j = 0; j < 8; ++j) {
            byte = (byte << 1) | (encoded_codes_lengths[i + j] - '0');
        }
        encoded_codes_lengths_body += static_cast<char>(byte);
    }

    std::string result;

    uint32_t length = bytes.size();
    result += static_cast<char>((length >> 24) & 0xFF);
    result += static_cast<char>((length >> 16) & 0xFF);
    result += static_cast<char>((length >> 8) & 0xFF);
    result += static_cast<char>(length & 0xFF);

    result += encoded_codes_lengths_tree;
    result += encoded_codes_lengths_body;
    result += encoded_body;

    return result;
}

std::vector<int> decode_code_lengths_lengths(const std::string& header) {
    auto bytes = string_to_bytes(header);
    std::string bits;
    for (auto ch : bytes) {
        bits += pad_left(to_binary(ch, 8), 8, '0');
    }

    std::vector<int> code_lengths;
    for (int e = 0; e <= 18; ++e) {
        int start_bit = e * 3;
        std::string three_bits = bits.substr(start_bit, 3);
        int length = std::stoi(three_bits, nullptr, 2);
        code_lengths.push_back(length);
    }

    return code_lengths;
}

std::pair<std::vector<int>, int> decode_codes_lengths_with_position(const std::string& header, const std::vector<std::optional<std::string>>& codes_lengths_tree) {
    auto bytes = string_to_bytes(header);
    std::string bits;
    for (auto b : bytes) {
        bits += pad_left(to_binary(b, 8), 8, '0');
    }

    std::map<std::string, int> tree_inv;
    for (int i = 0; i < codes_lengths_tree.size(); ++i) {
        if (codes_lengths_tree[i].has_value()) {
            tree_inv[codes_lengths_tree[i].value()] = i;
        }
    }

    int bit_pos = 0;
    std::string buf;
    std::vector<int> res;

    while (bit_pos < bits.length() && res.size() < 256) {
        buf += bits[bit_pos];
        bit_pos++;

        if (tree_inv.count(buf)) {
            int symbol = tree_inv[buf];
            buf.clear();

            if (symbol == 16) {
                std::string extra_bits_str = bits.substr(bit_pos, 2);
                int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
                bit_pos += 2;
                int repeats = 3 + extra_bits;
                for (int i = 0; i < repeats; ++i) res.push_back(res.back());
            } else if (symbol == 17) {
                std::string extra_bits_str = bits.substr(bit_pos, 3);
                int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
                bit_pos += 3;
                int repeats = 3 + extra_bits;
                for (int i = 0; i < repeats; ++i) res.push_back(0);
            } else if (symbol == 18) {
                std::string extra_bits_str = bits.substr(bit_pos, 7);
                int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
                bit_pos += 7;
                int repeats = 11 + extra_bits;
                for (int i = 0; i < repeats; ++i) res.push_back(0);
            } else {
                res.push_back(symbol);
            }
        }
    }

    return {res, bit_pos};
}

std::string decode(const std::string& message) {
    auto bytes = string_to_bytes(message);

    uint32_t length = (static_cast<uint32_t>(bytes[0]) << 24) |
                      (static_cast<uint32_t>(bytes[1]) << 16) |
                      (static_cast<uint32_t>(bytes[2]) << 8) |
                      static_cast<uint32_t>(bytes[3]);

    std::string header1 = message.substr(4, 8);

    auto code_lengths_lengths = decode_code_lengths_lengths(header1);
    auto tree = recreate_huffman_codes(code_lengths_lengths);

    std::string header2_start = message.substr(12);
    auto [codes_lengths, pos] = decode_codes_lengths_with_position(header2_start, tree);

    int header2_byte_length = (pos + 7) / 8;
    std::string body = message.substr(12 + header2_byte_length);

    auto codes = recreate_huffman_codes(codes_lengths);

    auto body_bytes = string_to_bytes(body);
    std::string bits;
    for (auto b : body_bytes) {
        bits += pad_left(to_binary(b, 8), 8, '0');
    }

    std::map<std::string, int> tree_inv;
    for (int i = 0; i < codes.size(); ++i) {
        if (codes[i].has_value()) {
            tree_inv[codes[i].value()] = i;
        }
    }

    std::vector<uint8_t> res;
    std::string buf;

    for (char bit : bits) {
        buf += bit;

        if (tree_inv.count(buf)) {
            res.push_back(tree_inv[buf]);
            buf.clear();

            if (res.size() >= length) {
                break;
            }
        }
    }

    return bytes_to_string(res);
}

int main(int argc, char* argv[]) {
    if (argc != 2 || (std::string(argv[1]) != "encode" && std::string(argv[1]) != "decode")) {
        std::cerr << "Usage: " << argv[0] << " encode|decode < input > output\n";
        return 1;
    }

    std::string input((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());

    if (std::string(argv[1]) == "encode") {
        std::cout << encode(input);
    } else {
        std::cout << decode(input);
    }

    return 0;
}


