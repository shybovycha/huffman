# Huffman encoding

This repo contains a few samples of how [Huffman encoding](https://en.wikipedia.org/wiki/Huffman_coding) is used in two popular data compression algorithms - DEFLATE (used in ZIP / 7ZIP / RAR / GZIP) and DHT (used in JPEG).

**NOTE:** the implementations are trivial and are meant more as an example rather than a real-world full-scale ZIP implementation.

Full description of how these work and how the algorithms are implemented could be found in [this blog]().

## DEFLATE

The full implementation is contained in the `simple_deflate.rb` module. The API is quite simple: `SimpleDeflate.encode(string)` and `SimpleDeflate.decode(string)`.

## DHT

The implementation in the `simple_dht.rb` has the same API as the DEFLATE implementation: `SimpleDHT.encode(string)` and `SimpleDHT.decode(string)`.
