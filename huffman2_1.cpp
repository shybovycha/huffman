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

Node* buildHuffmanTree(std::string_view s) {
  std::map<char, int> freq;

  for (auto i : s) {
    if (freq.find(i) == freq.end()) {
      freq[i] = 1;
    } else {
      freq[i]++;
    }
  }

  auto cmpNode = [](Node *a, Node *b) {
    if (a->count != b->count) {
      return a->count > b->count;
    }

    if ((a->c == static_cast<char>(255)) != (b->c == static_cast<char>(255))) {
      return b->c == static_cast<char>(255);
    }

    return a->c < b->c;
  };

  std::priority_queue<Node *, std::vector<Node *>, decltype(cmpNode)> pq(
      cmpNode);

  for (auto i : freq) {
    pq.push(new Node{
        .c = i.first, .count = i.second, .left = nullptr, .right = nullptr});
  }

  while (pq.size() > 1) {
    auto *left = pq.top();
    pq.pop();

    auto *right = pq.top();
    pq.pop();

    if (left->count < right->count) {
      std::swap(left, right);
    }

    pq.push(new Node{.c = static_cast<char>(255),
                     .count = left->count + right->count,
                     .left = left,
                     .right = right});
  }

  return pq.top();
}

std::string encode(Node* tree, std::string_view s) {
  std::queue<CodeNode *> q;

  q.push(new CodeNode{.node = tree, .code = std::string()});

  std::map<char, std::string> codes;

  while (!q.empty()) {
    auto *e = q.front();
    q.pop();

    if (!e->node->left && !e->node->right) {
      codes[e->node->c] = e->code;
      continue;
    }

    if (e->node->left) {
      q.push(new CodeNode{.node = e->node->left, .code = e->code + "0"});
    }

    if (e->node->right) {
      q.push(new CodeNode{.node = e->node->right, .code = e->code + "1"});
    }
  }

  std::string res = "";

  for (auto ch : s) {
    res += codes[ch];
  }

  return res;
}

std::string decode(Node* tree, std::string_view s) {
  std::string res = "";
  auto root = tree;

  for (auto ch : s) {
    if (ch == '0') {
      root = root->left;
    } else {
      root = root->right;
    }

    if (!root->left && !root->right) {
      res += root->c;
      root = tree;
    }
  }

  return res;
}

int main() {
    const std::string s = "Hello world";

    auto root = buildHuffmanTree(s);
    
    auto encoded = encode(root, s);
    auto decoded = decode(root, encoded);

    std::cout << "Input: " << s << std::endl;
    std::cout << "Encoded: " << encoded << std::endl;
    std::cout << "Decoded: " << decoded << std::endl;

    return 0;
}
