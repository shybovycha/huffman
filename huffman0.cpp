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

    std::priority_queue<std::shared_ptr<Node>, std::vector<std::shared_ptr<Node>>, decltype(cmpNode)> pq(cmpNode);

    for (auto i : freq) {
        pq.push(std::make_shared<Node>(Node{.c = i.first, .count = i.second, .left = nullptr, .right = nullptr}));
    }

    while (pq.size() > 1) {
        auto left = pq.top();
        pq.pop();

        auto right = pq.top();
        pq.pop();

        pq.push(std::make_shared<Node>(Node{ .c = static_cast<char>(255), .count = left->count + right->count, .left = left, .right = right }));
    }

    std::queue<std::shared_ptr<CodeNode>> q;

    q.push(std::make_shared<CodeNode>(CodeNode{ .node = pq.top(), .code = std::string() }));

    std::map<char, std::string> codes;

    while (!q.empty()) {
        auto e = q.front();
        q.pop();

        if (!e->node->left && !e->node->right) {
            codes[e->node->c] = e->code;
            continue;
        }

        if (e->node->left) {
            q.push(std::make_shared<CodeNode>(CodeNode{ .node = e->node->left, .code = e->code + "0" }));
        }

        if (e->node->right) {
            q.push(std::make_shared<CodeNode>(CodeNode{ .node = e->node->right, .code = e->code + "1" }));
        }
    }

    for (auto i : codes) {
        std::cout << "'" << i.first << "'" << ": " << i.second << std::endl;
    }

    return 0;
}
