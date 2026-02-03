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

        // if (left->count < right->count) {
        //     std::swap(left, right);
        // }

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

    // std::cout << "Sorted codes:" << std::endl;

    // for (auto [ch, code] : sorted_codes) {
    //     std::cout << "'" << ch << "'" << ": " << code << std::endl;
    // }

    std::map<char, std::string> canonical_codes;

    int curr_code = 0;
    int prev_length = 0;

    for (auto [ch, code] : sorted_codes) {
        curr_code <<= (code.length() - prev_length);
        canonical_codes[ch] = std::bitset<32>(curr_code).to_string().substr(32 - code.length());
        curr_code++;
        prev_length = code.length();
    }

    std::cout << "Canonical codes:" << std::endl;

    for (auto [ch, code] : canonical_codes) {
        std::cout << "'" << ch << "'" << ": " << code << std::endl;
    }

    return 0;
}
