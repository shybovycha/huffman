#include <string>
#include <map>
#include <queue>
#include <iostream>

struct Node {
    char c;
    int count;
    Node* left;
    Node* right;
};

struct CodeNode {
    Node* node;
    std::string code;
};

struct CodeLengthNode {
    size_t length;
    int extra_bits;
};

int main() {
    const std::string s = "Hello world";

    std::map<char, int> freq;

    for (auto i : s) {
        if (freq.find(i) == freq.end()) {
            freq[i] = 1;
        } else {
            freq[i]++;
        }
    }

    auto cmpNode = [](Node* a, Node* b) {
        if (a->count != b->count) {
            return a->count > b->count;
        }

        if ((a->c == static_cast<char>(255)) != (b->c == static_cast<char>(255))) {
            return false;
        }

        return a->c < b->c;
    };

    std::priority_queue<Node*, std::vector<Node*>, decltype(cmpNode)> pq(cmpNode);

    for (auto i : freq) {
        pq.push(new Node{.c = i.first, .count = i.second, .left = nullptr, .right = nullptr});
    }

    while (pq.size() > 1) {
        auto* left = pq.top();
        pq.pop();

        auto* right = pq.top();
        pq.pop();

        pq.push(new Node{ .c = static_cast<char>(255), .count = left->count + right->count, .left = left, .right = right });
    }

    std::queue<CodeNode*> q;

    q.push(new CodeNode{ .node = pq.top(), .code = std::string() });

    std::map<char, std::string> codes;

    while (!q.empty()) {
        auto* e = q.front();
        q.pop();

        if (!e->node->left && !e->node->right) {
            codes[e->node->c] = e->code;
            continue;
        }

        if (e->node->left) {
            q.push(new CodeNode{ .node = e->node->left, .code = e->code + "0" });
        }

        if (e->node->right) {
            q.push(new CodeNode{ .node = e->node->right, .code = e->code + "1" });
        }
    }

    std::cout << "Codes:" << std::endl;

    for (auto [ch, code] : codes) {
        std::cout << "'" << ch << "'" << ": " << code << std::endl;
    }

    std::vector<std::pair<char, std::string>> sorted_codes(codes.begin(), codes.end());

    std::sort(sorted_codes.begin(), sorted_codes.end(),
        [](const auto& a, const auto& b) {
            if (a.second.length() != b.second.length()) {
                return a.second.length() < b.second.length();
            }

            return a.first < b.first;
        });

    std::map<char, std::string> canonical_codes;

    int curr_code = 0;
    int prev_length = 0;

    for (auto [ch, code] : sorted_codes) {
        curr_code <<= (code.length() - prev_length);
        canonical_codes[ch] = std::bitset<32>(curr_code).to_string().substr(32 - code.length());
        curr_code++;
        prev_length = code.length();
    }

    // std::cout << "Sorted codes:" << std::endl;

    // for (auto [ch, code] : sorted_codes) {
    //     std::cout << "'" << ch << "'" << ": " << code << std::endl;
    // }

    std::cout << "Canonical codes:" << std::endl;

    for (auto [ch, code] : canonical_codes) {
        std::cout << "'" << ch << "'" << ": " << code << std::endl;
    }

    std::vector<CodeLengthNode*> code_lengths;

    for (auto i = 0; i < 256; i++) {
        auto length = canonical_codes[i].length();
        auto run_length = 1;

        while (i + run_length < 256 && canonical_codes[i + run_length].length() == length) {
            run_length++;
        }

        // std::cout << ">> found " << run_length << " occurrences of " << length << "("<<(char)i<<"/"<<canonical_codes[i]<<")" << std::endl;

        i += run_length - 1;

        if (length == 0) {
            while (run_length > 0) {
                if (run_length >= 11) {
                    // code 18, repeat '0' 11..138 times
                    auto diff = std::min(138, std::max(11, run_length));

                    code_lengths.push_back(new CodeLengthNode{ .length = 18, .extra_bits = diff - 11 });

                    run_length -= diff;
                }
                else if (run_length >= 3) {
                    // code 17, repeat '0' 3..10 times
                    auto diff = std::min(10, std::max(3, run_length));

                    code_lengths.push_back(new CodeLengthNode{ .length = 17, .extra_bits = diff - 3 });

                    run_length -= diff;
                }
                else {
                    for (auto t = 0; t < run_length; t++) {
                        code_lengths.push_back(new CodeLengthNode{ .length = 0, .extra_bits = 0 });
                    }

                    run_length = 0;
                }
            }
        }
        else if (length != 0 && run_length >= 3) {
            code_lengths.push_back(new CodeLengthNode{ .length = length, .extra_bits = 0 });
            run_length--;

            while (run_length > 0) {
                auto diff = std::min(6, std::max(3, run_length));
                code_lengths.push_back(new CodeLengthNode{ .length = 16, .extra_bits = diff - 3 });
                run_length -= diff;
            }
        }
        else {
            for (auto t = 0; t < run_length; t++) {
                code_lengths.push_back(new CodeLengthNode{ .length = length, .extra_bits = 0 });
            }

            run_length = 0;
        }
    }

    std::cout << "Code lengths:" << std::endl;

    for (auto i : code_lengths) {
        if (i->length < 16) {
            std::cout << i->length << std::endl;
        } else if (i->length == 16 || i->length == 17 || i->length == 18) {
            std::cout << "(" << i->length << ", " << static_cast<int>(i->extra_bits) << " / " << std::bitset<8>(i->extra_bits).to_string() << ")" << std::endl;
        }
    }

    return 0;
}
