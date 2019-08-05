#
# Ruby automated riddlebot solver
#
# Can you write a program that solves them all?
#
require "net/http"
require "json"
require "open-uri"

WORDS_FILE = open("https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt")
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
    
    # get riddle answer
    if riddle_type == "reverse"
      answer = riddle_text.reverse
    elsif riddle_type == "rot13"
      answer = ""
      chars = riddle_text.split("")
      chars.each do |c|
        if c == " "
          answer += c
        elsif c.ord < 78
          answer += (c.ord + 13).chr
        else
          answer += (c.ord - 13).chr
        end
      end
    elsif riddle_type == "caesar"
      answer = ""
      if next_riddle.key?('riddleKey')
        riddle_key = next_riddle['riddleKey']
      else
        words = riddle_text.split(" ")
        words.each do |word|
          if word.length == 1
            riddle_key = word.ord - 65  # assume words with 1 letter are "A"
          end
        end
      end
      chars = riddle_text.split("")
      chars.each do |c|
        if c == " "
          answer += c
        else
          new_c = (c.ord - riddle_key).chr
          if new_c.ord < 65
            new_c = (new_c.ord + 26).chr
          end
          answer += new_c
        end
      end
    elsif riddle_type == "vigenere"
      answer = ""
      if next_riddle.key?('riddleKey')
        riddle_key = next_riddle['riddleKey']
      else
        i = 0  # char counter including spaces
        j = 0  # char counter excluding spaces
        chars_split = [[], [], [], []]
        while i < riddle_text.length
          if riddle_text[i] != " "
            chars_split[j % 4].push(riddle_text[i])
            j += 1
          end
          i += 1
        end
        test = "WEATHER FORECAST FOR THIS WEEK MONDAY THUNDERSTORM ICE PELLETS TUESDAY THUNDERSTORM SHOWERS IN VICINITY WEDNESDAY HEAVY SAND STORM THURSDAY HEAVY SNOW SHOWERS FOG FRIDAY HEAVY SHOWERS RAIN SUNDAY PARTLY CLOUDY AND WINDY NEXT WEEK FRIDAY THUNDERSTORM IN VICINITY SUNDAY HEAVY SNOW SHOWERS MONDAY LIGHT THUNDERSTORM RAIN HAIL HAZE TUESDAY HEAVY SHOWERS RAIN WEDNESDAY OVERCAST AND BREEZY THURSDAY HEAVY FREEZING DRIZZLE RAIN"
        puts "is english? #{english?(test)}"
        riddle_key = [0, 0, 0, 0]
      end
      index = 0
      chars = riddle_text.split("")
      chars.each do |c|
        if c == " "
          answer += c
        else
          new_c = (c.ord - riddle_key[index % riddle_key.length]).chr
          if new_c.ord < 65
            new_c = (new_c.ord + 26).chr
          end
          answer += new_c
          index += 1
        end
      end
    else
      answer = ""
    end

    # send to riddlebot api
    answer_result = send_answer(riddle_path, answer)

    if answer_result['result'] == 'completed'
      puts 'All riddles answered correctly!'
      puts 'certificate:'
      puts answer_result['certificate']
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

# create hash for frequencies of array elements
def frequencies(arr)
  freq = Hash.new(0)
  arr.each do |element|
    freq[element] += 1
  end
  freq = freq.sort_by { |element, count| count }
  freq.reverse!
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
