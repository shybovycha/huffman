# Huffman encoding

This repo contains a few samples of how [Huffman encoding](https://en.wikipedia.org/wiki/Huffman_coding) is used in two popular data compression algorithms - DEFLATE (used in ZIP / 7ZIP / RAR / GZIP) and DHT (used in JPEG).

**NOTE:** the implementations are trivial and are meant more as an example rather than a real-world full-scale ZIP implementation.

Full description of how these work and how the algorithms are implemented could be found in [this blog](https://shybovycha.github.io/2025/12/01/data-compression.html).

## Algorithms

### DEFLATE

The full implementation is contained in the `simple_deflate.rb` module. The API is quite simple: `SimpleDeflate.encode(string)` and `SimpleDeflate.decode(string)`.

### DHT

The implementation in the `simple_dht.rb` has the same API as the DEFLATE implementation: `SimpleDHT.encode(string)` and `SimpleDHT.decode(string)`.

## Running code

There are few implementations of the algorithms - in C++, Ruby and Crystal.


### C++

Simply use a C++20-compatible compiler:

```bash
$ c++ -std=c++20 simple_dht.cpp -o simple_dht
$ # or for MacOSX
$ clang++ -std=c++20 simple_dht.cpp -o simple_dht
```

Then run the program with either `encode` or `decode` argument.
It will then take all of STDIN and either encode or, correspondingly, decode it and print the output to STDOUT.
This allows you to pipe the input and the output to/from files efficiently:

```bash
$ cat source.bin | ./simple_dht encode >encoded.bin
$ cat encoded.bin | ./simple_dht decode >decoded.bin
```

### Ruby

Simply run Ruby interpreter, using the same `encode` or `decode` argument to the program and STDIN for input:

```bash
$ cat source.bin | ruby simple_deflate.rb encode >encoded.bin
$ cat encoded.bin | ruby simple_deflate.rb decode >decoded.bin
```

### Crystal

You can use either the Ruby-way (interpreter) to run code immediately:

```bash
$ cat source.bin | crystal simple_deflate.cr encode >encoded.bin
$ cat encoded.bin | crystal simple_deflate.cr decode >decoded.bin
```

Or C++ way, compiling a native binary and runnint that one instead of interpreter:

```bash
$ crystal build simple_deflate.cr
$ cat source.bin | ./simple_deflate encode >encoded.bin
$ cat encoded.bin | ./simple_deflate decode >decoded.bin
```
