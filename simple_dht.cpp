#include <algorithm>
#include <bitset>
#include <iostream>
#include <map>
#include <queue>
#include <string>
#include <vector>

struct Node {
  char c;
  int count;
  Node *left;
  Node *right;
};

struct CodeNode {
  Node *node;
  std::string code;
};

Node *buildTree(const std::string &s) {
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

  std::priority_queue<Node *, std::vector<Node *>, decltype(cmpNode)> pq(cmpNode);

  for (auto i : freq) {
    pq.push(new Node{.c = i.first, .count = i.second, .left = nullptr, .right = nullptr});
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

std::map<char, std::string> buildTable(Node *tree) {
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

  return codes;
}

std::map<char, std::string> buildCanonicalTable(const std::map<char, std::string> &codes) {
  std::vector<std::pair<char, std::string>> sorted_codes(codes.begin(), codes.end());

  std::sort(sorted_codes.begin(), sorted_codes.end(), [](const auto &a, const auto &b) {
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

  return canonical_codes;
}

std::vector<std::string> recreateHuffmanCodes(const std::vector<int> &code_lengths) {
  std::vector<std::pair<int, int>> symbols_with_lengths;

  for (int i = 0; i < code_lengths.size(); ++i) {
    if (code_lengths[i] > 0) {
      symbols_with_lengths.push_back({i, code_lengths[i]});
    }
  }

  std::sort(symbols_with_lengths.begin(), symbols_with_lengths.end(), [](const auto &a, const auto &b) {
    if (a.second != b.second) {
      return a.second < b.second;
    }

    return a.first < b.first;
  });

  std::vector<std::string> res(code_lengths.size());
  int prev_length = 0;
  int code = 0;

  for (auto [s, len] : symbols_with_lengths) {
    code <<= (len - prev_length);
    res[s] = std::bitset<32>(code).to_string().substr(32 - len);
    code++;
    prev_length = len;
  }

  return res;
}

std::string encode(const std::string &message) {
  auto *tree = buildTree(message);
  auto codes = buildTable(tree);
  auto canonical_codes = buildCanonicalTable(codes);

  std::map<size_t, int> codes_count_by_length;
  for (auto [ch, code] : canonical_codes) {
    codes_count_by_length[code.length()]++;
  }

  std::vector<int> header1;
  for (int len = 1; len <= 15; ++len) {
    header1.push_back(codes_count_by_length[len]);
  }

  std::vector<std::pair<char, std::string>> sorted_codes(canonical_codes.begin(), canonical_codes.end());
  
  std::sort(sorted_codes.begin(), sorted_codes.end(), [](const auto &a, const auto &b) {
    if (a.second.length() != b.second.length()) {
      return a.second.length() < b.second.length();
    }

    return a.first < b.first;
  });

  std::vector<char> header2;
  for (auto [ch, code] : sorted_codes) {
    header2.push_back(ch);
  }

  std::string body_bits;
  for (auto ch : message) {
    body_bits += canonical_codes[ch];
  }

  while (body_bits.length() % 8 != 0) {
    body_bits += '0';
  }

  std::vector<char> body;
  for (size_t i = 0; i < body_bits.length(); i += 8) {
    char byte = 0;
    for (int j = 0; j < 8; ++j) {
      byte = (byte << 1) | (body_bits[i + j] - '0');
    }
    body.push_back(byte);
  }

  std::string result;

  auto length = static_cast<uint32_t>(message.length());
  result += static_cast<char>((length >> 24) & 0xFF);
  result += static_cast<char>((length >> 16) & 0xFF);
  result += static_cast<char>((length >> 8) & 0xFF);
  result += static_cast<char>(length & 0xFF);

  for (auto count : header1) {
    result += static_cast<char>(count);
  }
  for (auto ch : header2) {
    result += ch;
  }
  for (auto byte : body) {
    result += byte;
  }

  return result;
}

std::string decode(const std::string &message) {
  auto length =
      static_cast<uint32_t>((static_cast<unsigned char>(message[0]) << 24) |
                            (static_cast<unsigned char>(message[1]) << 16) |
                            (static_cast<unsigned char>(message[2]) << 8) |
                            static_cast<unsigned char>(message[3]));

  std::vector<int> counts_encoded;
  for (int i = 4; i < 19; ++i) {
    counts_encoded.push_back(static_cast<unsigned char>(message[i]));
  }

  std::vector<int> counts;
  for (int len = 0; len < counts_encoded.size(); ++len) {
    for (int i = 0; i < counts_encoded[len]; ++i) {
      counts.push_back(len + 1);
    }
  }

  auto codes = recreateHuffmanCodes(counts);

  std::vector<std::string> codes_compact;
  for (auto &code : codes) {
    if (!code.empty()) {
      codes_compact.push_back(code);
    }
  }

  std::vector<char> symbols;
  for (size_t i = 0; i < codes_compact.size(); ++i) {
    symbols.push_back(message[19 + i]);
  }

  std::string body_bits;
  for (size_t i = 19 + codes_compact.size(); i < message.length(); ++i) {
    auto byte = static_cast<unsigned char>(message[i]);
    body_bits += std::bitset<8>(byte).to_string();
  }

  std::map<std::string, char> table;
  for (size_t i = 0; i < codes_compact.size(); ++i) {
    table[codes_compact[i]] = symbols[i];
  }

  std::string res;
  std::string buf;

  for (auto bit : body_bits) {
    buf += bit;

    if (table.find(buf) != table.end()) {
      res += table[buf];
      buf.clear();

      if (res.length() >= length) {
        break;
      }
    }
  }

  return res;
}

int main(int argc, char *argv[]) {
  if (argc != 2 || (std::string(argv[1]) != "encode" && std::string(argv[1]) != "decode")) {
    std::cerr << "Usage: " << argv[0] << " encode|decode < input > output\n";
    return 1;
  }

  std::string input((std::istreambuf_iterator<char>(std::cin)),
                    std::istreambuf_iterator<char>());

  if (std::string(argv[1]) == "encode") {
    std::cout << encode(input);
  } else {
    std::cout << decode(input);
  }

  return 0;
}
