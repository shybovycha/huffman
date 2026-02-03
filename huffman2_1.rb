def encode(s)
  a = s.chars.uniq.map {|c| {char: c, count: s.chars.count(c)}}.sort {|a, b| [b[:count], a[:char]] <=> [a[:count], b[:char]]}
  pq = a.map { |c| {char: c[:char], count: c[:count], left: nil, right: nil} }

  while pq.size > 1 do
    left, right = pq.pop(2)

    if left[:count] < right[:count]
      left, right = right, left
    end

    pq << {char: nil, count: left[:count] + right[:count], left: left, right: right}

    pq.sort! {|a,b| [b[:count], a[:char] || ''] <=> [a[:count], b[:char] || '']}
  end

  q = [{node: pq[0], code: ''}]

  codes = {}

  while q.size > 0 do
    e = q.shift

    if e[:node][:left].nil? && e[:node][:right].nil?
      codes[e[:node][:char]] = e[:code]
      next
    end

    q.push({node: e[:node][:left], code: e[:code] + '0'}) if !e[:node][:left].nil?

    q.push({node: e[:node][:right], code: e[:code] + '1'}) if !e[:node][:right].nil?
  end

  encoded = s.chars.map {|c| codes[c]}.join
  
  { tree: pq[0], encoded: encoded }
end

def decode(tree, encoded)
  root = tree
  res = ''

  encoded.chars.each do |c|
    root = if c == '0' then root[:left] else root[:right] end

    if not root[:char].nil?
      res += root[:char]
      root = tree
    end
  end

  res
end

s = 'Hello world'
encode(s) => { tree:, encoded: }
decoded = decode(tree, encoded)

puts "Input: #{s}"
puts "Encoded: #{encoded}"
puts "Decoded: #{decoded}"
