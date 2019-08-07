#
# Ruby automated riddlebot solver
#
# Can you write a program that solves them all?
#
require "net/http"
require "json"
require "open-uri"

WORDS_FILE = open("https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt")  # credit to the google-10000-english repo
WORDS_BY_FREQUENCY = WORDS_FILE.read.split("\n")
CHARS_BY_FREQUENCY = "ETAOINSHRDLCUMWFGYPBVKJXQZ"

def main
  # get started -- replace with your login
  start = post_json('/riddlebot/start', { :login => 'amber-king' })

  riddle_path = start['riddlePath']

  next_riddle = get_json(riddle_path)
  # Answer each question, as log as we are correct
  #
  loop do
    # print out the map
    puts
    puts "Riddlebot says:"
    puts next_riddle['message']
    puts

    riddle_type = next_riddle['riddleType']
    riddle_text = next_riddle['riddleText']
    
    if riddle_type == "reverse"
      answer = solve_reverse(riddle_text)
    elsif riddle_type == "rot13"
      answer = solve_rot13(riddle_text)
    elsif riddle_type == "caesar"
      if next_riddle.key?('riddleKey')
        riddle_key = next_riddle['riddleKey']
      else
        riddle_key = get_caesar_key(riddle_text)
      end
      answer = solve_caesar(riddle_text, riddle_key)
    elsif riddle_type == "vigenere"
      if next_riddle.key?('riddleKey')
        riddle_key = next_riddle['riddleKey']
        answer = solve_vigenere(riddle_text, riddle_key)
      else
        riddle_key = get_vigenere_key(riddle_text.reverse)
        answer = solve_vigenere(riddle_text.reverse, riddle_key)
      end
    end
    
    # send to riddlebot api
    answer_result = send_answer(riddle_path, answer)

    if answer_result['result'] == 'completed'
      puts 'All riddles answered correctly!'
      puts 'certificate:'
      puts answer_result['certificate']
      exit 1
    elsif answer_result['result'] == 'correct'
      riddle_path = answer_result['nextRiddlePath']
      next_riddle = get_json(riddle_path)
    else
      puts('uh oh! wrong answer.')
      exit 1
    end
  end
end

def send_answer(path, answer)
  post_json(path, { :answer => answer })
end

# get data from the api and parse it into a ruby hash
def get_json(path)
  puts "*** GET #{path}"

  response = Net::HTTP.get_response(build_uri(path))
  result = JSON.parse(response.body)
  puts "HTTP #{response.code}"

  #puts JSON.pretty_generate(result)
  result
end

# post an answer to the noops api
def post_json(path, body)
  uri = build_uri(path)
  puts "*** POST #{uri}"
  puts JSON.pretty_generate(body)

  post_request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  post_request.body = JSON.generate(body)

  response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
    http.request(post_request)
  end

  puts "HTTP #{response.code}"
  result = JSON.parse(response.body)
  puts result[:result]
  result
end

def build_uri(path)
  URI.parse("https://api.noopschallenge.com" + path)
end

def solve_reverse(riddle)
  return riddle.reverse
end

def solve_rot13(riddle)
  answer = ""
  chars = riddle.split("")
  chars.each do |c|
    if c == " "
      answer += c
    elsif c.ord < 78
      answer += (c.ord + 13).chr
    else
      answer += (c.ord - 13).chr
    end
  end
  return answer
end

def solve_caesar(riddle, key)
  answer = ""
  chars = riddle.split("")
  chars.each do |c|
    if c == " " || c == "-"
      answer += c
    else
      new_c = (c.ord - key).chr
      if new_c.ord < 65
        new_c = (new_c.ord + 26).chr
      end
      answer += new_c
    end
  end
  return answer
end

def get_caesar_key(riddle)
  key = 0
  words = riddle.split(" ")
  words.each do |word|
    if word.length == 1
      key = word.ord - 65  # assume words with 1 letter are "A"
    end
  end
  return key
end

def solve_vigenere(riddle, key)
  answer = ""
  index = 0
  chars = riddle.split("")
  chars.each do |c|
    if c == " "
      answer += c
    else
      new_c = (c.ord - key[index % key.length]).chr
      if new_c.ord < 65
        new_c = (new_c.ord + 26).chr
      end
      answer += new_c
      index += 1
    end
  end
  return answer
end

def get_vigenere_key(riddle)  # not the best method (only works sometimes)
  chars_split = split_chars(riddle)
    
  freq_arr = []
  for i in 0..3
    freq_hash = frequencies(chars_split[i])
    freq_arr.push(freq_hash)
  end
   
  # get the possible keys from setting the 3 most frequent characters of each group to E (3^4 combinations)
  possible_keys = []
  for i in 0..3
    offsets = []
    for j in 0..2
      new_e = freq_arr[i].keys[j]
      offset = new_e.ord - 69
      if offset < 0
        offset += 26
      end
      offsets.push(offset)
    end
    possible_keys.push(offsets)
  end
  possible_keys = possible_keys.first.product(*possible_keys[1..-1]).map(&:flatten)
  
  # test each key
  possible_keys.each do |key|
    text = solve_vigenere(riddle, key)
    if english?(text)
      return key
    end
  end

  return [0, 0, 0, 0]
end

# create arrays grouping the characters of the different offsets
def split_chars(riddle)
  i = 0  # char counter including spaces
  j = 0  # char counter excluding spaces
  chars_split = [[], [], [], []]
  while i < riddle.length
    if riddle[i] != " "
      chars_split[j % 4].push(riddle[i])
      j += 1
    end
    i += 1
  end
  return chars_split
end

# create hash for frequencies of char array elements
def frequencies(chars)
  freq = Hash.new(0)
  chars.each do |char|
    freq[char] += 1
  end
  freq = freq.sort_by { |char, count| count }  # order by highest frequency
  freq.reverse!
  freq = Hash[freq]
  return freq
end

# return true if >75% of words are English, false otherwise
def english?(text)
  num_english = 0
  text_words = text.split(" ")
  text_words.each do |text_word|
    WORDS_BY_FREQUENCY.each do |dict_word|
      if text_word == dict_word.upcase
        num_english += 1
        break
      end
    end
  end
  return num_english.to_f / text_words.length > 0.75
end

main()
