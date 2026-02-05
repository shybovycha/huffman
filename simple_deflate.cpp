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

struct CodeLengthNode {
  size_t length;
  int extra_bits;
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

    pq.push(new Node{.c = static_cast<char>(255), .count = left->count + right->count, .left = left, .right = right});
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

std::map<char, std::string>
buildCanonicalTable(const std::map<char, std::string> &codes) {
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

std::vector<CodeLengthNode*> runningCodesLengths(const std::map<char, std::string> &codes) {
  std::vector<int> codes_lengths(256, 0);
  for (auto [byte, code] : codes) {
    codes_lengths[static_cast<unsigned char>(byte)] = code.length();
  }

  std::vector<CodeLengthNode *> result;
  size_t i = 0;

  while (i < codes_lengths.size()) {
    auto length = codes_lengths[i];
    auto run_length = 1;

    while (i + run_length < codes_lengths.size() && codes_lengths[i + run_length] == length) {
      run_length++;
    }

    i += run_length;

    if (length == 0) {
      while (run_length > 0) {
        if (run_length >= 11) {
          auto diff = std::min(138, std::max(11, run_length));
          result.push_back(new CodeLengthNode{.length = 18, .extra_bits = diff - 11});
          run_length -= diff;
        } else if (run_length >= 3) {
          auto diff = std::min(10, std::max(3, run_length));
          result.push_back(new CodeLengthNode{.length = 17, .extra_bits = diff - 3});
          run_length -= diff;
        } else {
          for (auto t = 0; t < run_length; t++) {
            result.push_back(new CodeLengthNode{.length = 0, .extra_bits = 0});
          }

          run_length = 0;
        }
      }
    } else if (length != 0 && run_length >= 3) {
      result.push_back(new CodeLengthNode{.length = static_cast<size_t>(length), .extra_bits = 0});
      run_length--;

      while (run_length >= 3) {
        auto diff = std::min(6, std::max(3, run_length));
        result.push_back(new CodeLengthNode{.length = 16, .extra_bits = diff - 3});
        run_length -= diff;
      }
    }

    for (auto t = 0; t < run_length; t++) {
      result.push_back(new CodeLengthNode{.length = static_cast<size_t>(length), .extra_bits = 0});
    }
  }

  return result;
}

std::string encode(const std::string &message) {
  auto *tree = buildTree(message);
  auto codes = buildTable(tree);
  auto canonical_codes = buildCanonicalTable(codes);

  auto codes_lengths = runningCodesLengths(canonical_codes);

  std::vector<char> raw_codes_lengths;
  for (auto *item : codes_lengths) {
    raw_codes_lengths.push_back(static_cast<char>(item->length));
  }

  std::string raw_codes_str(raw_codes_lengths.begin(), raw_codes_lengths.end());
  auto *codes_lengths_tree = buildTree(raw_codes_str);
  auto codes_lengths_codes = buildTable(codes_lengths_tree);
  auto canonical_codes_lengths = buildCanonicalTable(codes_lengths_codes);

  std::string body_bits;
  for (auto c : message) {
    body_bits += canonical_codes[c];
  }

  while (body_bits.length() % 8 != 0) {
    body_bits += '0';
  }

  std::string encoded_body;
  for (size_t i = 0; i < body_bits.length(); i += 8) {
    char byte = 0;
    for (int j = 0; j < 8; ++j) {
      byte = (byte << 1) | (body_bits[i + j] - '0');
    }
    encoded_body += byte;
  }

  std::string encoded_codes_lengths;
  for (auto *c : codes_lengths) {
    if (c->length == 16 || c->length == 17 || c->length == 18) {
      int extra_bits = (c->length == 16) ? 2 : (c->length == 17) ? 3 : 7;
      encoded_codes_lengths += canonical_codes_lengths[static_cast<char>(c->length)];
      encoded_codes_lengths += std::bitset<8>(c->extra_bits).to_string().substr(8 - extra_bits);
    } else {
      encoded_codes_lengths += canonical_codes_lengths[static_cast<char>(c->length)];
    }
  }

  std::string bit_string;
  for (int c = 0; c <= 18; ++c) {
    int len = canonical_codes_lengths.find(static_cast<char>(c)) != canonical_codes_lengths.end() ? canonical_codes_lengths[static_cast<char>(c)].length() : 0;
    bit_string += std::bitset<3>(len).to_string();
  }

  while (bit_string.length() % 8 != 0) {
    bit_string += '0';
  }

  std::string encoded_codes_lengths_tree;
  for (size_t i = 0; i < bit_string.length(); i += 8) {
    char byte = 0;
    for (int j = 0; j < 8; ++j) {
      byte = (byte << 1) | (bit_string[i + j] - '0');
    }
    encoded_codes_lengths_tree += byte;
  }

  while (encoded_codes_lengths.length() % 8 != 0) {
    encoded_codes_lengths += '0';
  }

  std::string encoded_codes_lengths_body;
  for (size_t i = 0; i < encoded_codes_lengths.length(); i += 8) {
    char byte = 0;
    for (int j = 0; j < 8; ++j) {
      byte = (byte << 1) | (encoded_codes_lengths[i + j] - '0');
    }
    encoded_codes_lengths_body += byte;
  }

  std::string result;

  auto length = static_cast<uint32_t>(message.length());
  result += static_cast<char>((length >> 24) & 0xFF);
  result += static_cast<char>((length >> 16) & 0xFF);
  result += static_cast<char>((length >> 8) & 0xFF);
  result += static_cast<char>(length & 0xFF);

  result += encoded_codes_lengths_tree;
  result += encoded_codes_lengths_body;
  result += encoded_body;

  return result;
}

std::vector<int> decodeCodeLengthsLengths(const std::string &header) {
  std::string bits;
  for (auto ch : header) {
    bits += std::bitset<8>(static_cast<unsigned char>(ch)).to_string();
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

std::pair<std::vector<int>, int> decodeCodesLengthsWithPosition(const std::string &header, const std::vector<std::string> &codes_lengths_tree) {
  std::string bits;
  for (auto b : header) {
    bits += std::bitset<8>(static_cast<unsigned char>(b)).to_string();
  }

  std::map<std::string, int> tree_inv;
  for (int i = 0; i < codes_lengths_tree.size(); ++i) {
    if (!codes_lengths_tree[i].empty()) {
      tree_inv[codes_lengths_tree[i]] = i;
    }
  }

  int bit_pos = 0;
  std::string buf;
  std::vector<int> res;

  while (bit_pos < bits.length() && res.size() < 256) {
    buf += bits[bit_pos];
    bit_pos++;

    if (tree_inv.find(buf) != tree_inv.end()) {
      int symbol = tree_inv[buf];
      buf.clear();

      if (symbol == 16) {
        std::string extra_bits_str = bits.substr(bit_pos, 2);
        int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
        bit_pos += 2;
        int repeats = 3 + extra_bits;

        for (int i = 0; i < repeats; ++i) {
          res.push_back(res.back());
        }
      } else if (symbol == 17) {
        std::string extra_bits_str = bits.substr(bit_pos, 3);
        int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
        bit_pos += 3;
        int repeats = 3 + extra_bits;

        for (int i = 0; i < repeats; ++i) {
          res.push_back(0);
        }
      } else if (symbol == 18) {
        std::string extra_bits_str = bits.substr(bit_pos, 7);
        int extra_bits = std::stoi(extra_bits_str, nullptr, 2);
        bit_pos += 7;
        int repeats = 11 + extra_bits;

        for (int i = 0; i < repeats; ++i) {
          res.push_back(0);
        }
      } else {
        res.push_back(symbol);
      }
    }
  }

  return {res, bit_pos};
}

std::string decode(const std::string &message) {
  auto length =
      static_cast<uint32_t>((static_cast<unsigned char>(message[0]) << 24) |
                            (static_cast<unsigned char>(message[1]) << 16) |
                            (static_cast<unsigned char>(message[2]) << 8) |
                            static_cast<unsigned char>(message[3]));

  std::string header1 = message.substr(4, 8);

  auto code_lengths_lengths = decodeCodeLengthsLengths(header1);
  auto tree = recreateHuffmanCodes(code_lengths_lengths);

  std::string header2_start = message.substr(12);
  auto [codes_lengths, pos] = decodeCodesLengthsWithPosition(header2_start, tree);

  int header2_byte_length = (pos + 7) / 8;
  std::string body = message.substr(12 + header2_byte_length);

  auto codes = recreateHuffmanCodes(codes_lengths);

  std::string bits;
  for (auto b : body) {
    bits += std::bitset<8>(static_cast<unsigned char>(b)).to_string();
  }

  std::map<std::string, int> tree_inv;
  for (int i = 0; i < codes.size(); ++i) {
    if (!codes[i].empty()) {
      tree_inv[codes[i]] = i;
    }
  }

  std::string res;
  std::string buf;

  for (auto bit : bits) {
    buf += bit;

    if (tree_inv.find(buf) != tree_inv.end()) {
      res += static_cast<char>(tree_inv[buf]);
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

  std::string input((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());

  if (std::string(argv[1]) == "encode") {
    std::cout << encode(input);
  } else {
    std::cout << decode(input);
  }

  return 0;
}
