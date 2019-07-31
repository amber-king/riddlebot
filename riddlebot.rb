#
# Ruby automated riddlebot solver
#
# Can you write a program that solves them all?
#
require "net/http"
require "json"

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
            riddle_key = word.ord - 65  # assume words with 1 letter are "a"
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
        riddle_key = [0, 0, 0]
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
      answer = riddle_text
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

main()
