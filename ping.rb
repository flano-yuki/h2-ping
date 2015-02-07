#!/usr/bin/env ruby

require 'optparse'
require 'socket'
require 'openssl'
require 'http/2'
require 'uri'
DRAFT = 'h2-15'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ping.rb [options]"
  opts.on("-d", "--data [String]", "PING payload (8bytes)")     do |v| options[:payload] = v end
  opts.on("-i", "--interval [Integer]", "PING interval (sec)") do |v| options[:interval] = v end
  opts.on("-c", "--count [Integer]", "number of send frame") do |v| options[:count] = v end
  opts.on("-s", "--statics", "show statics when stop") do |v| options[:statics] = true end
  opts.on("-v", "--verbose", "show all frame info") do |v| options[:verbose] = true end
end.parse!
options[:interval] = 5 if options[:interval].nil?

uri = URI.parse(ARGV[0] || 'http://localhost:8080/')
tcp = TCPSocket.new(uri.host, uri.port)
sock = nil

t = Time.now

if uri.scheme == 'https'
  ctx = OpenSSL::SSL::SSLContext.new
  ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

  ctx.npn_protocols = [DRAFT]
  ctx.npn_select_cb = lambda do |protocols|
    puts "NPN protocols supported by server: #{protocols}"
    DRAFT if protocols.include? DRAFT
  end

  sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
  sock.sync_close = true
  sock.hostname = uri.hostname
  sock.connect

  if sock.npn_protocol != DRAFT
    puts "Failed to negotiate #{DRAFT} via NPN"
    exit
  end
else
  sock = tcp
end


counter = 0 #sended frame counter

def statics_message(max, min, sum, counter)
  "max:#{max}, min:#{min}, ave:#{sum / (counter + 1).to_f}"
end

def sended_message(counter, time, payload)
  "#{"% 4d" % counter}. #{time.strftime("%k:%M:%S")} Send PING (#{payload})... "
end

def recived_message(payload, elapsed)
  print "Recieve ACK (#{payload}) (#{elapsed}ms)\n"
end

#statics
max = 0
min = 0
sum = 0

conn = HTTP2::Client.new
conn.on(:frame) do |bytes|
  sock.print bytes
  sock.flush
end

conn.on(:frame_sent) do |frame|
  puts "Sent frame: #{frame.inspect}" if options[:verbose]
end

conn.on(:frame_received) do |frame|
  puts "Recive frame: #{frame.inspect}" if options[:verbose]
  if frame[:type] == :ping && frame[:flags].include?(:ack)
    #calculate elapsed time
    time = Time.now
    recived_time = (time.to_i * 1000 + time.usec / 1000.0).round
    sended_time = (t.to_i * 1000 + t.usec / 1000.0).round
    elapsed = recived_time - sended_time

    #for statics
    max = elapsed if max < elapsed
    min = elapsed if elapsed < min || min == 0
    sum += elapsed

    print recived_message(frame[:payload], elapsed)
    counter += 1
    exit(0) if options[:count] && counter == options[:count].to_i
    sleep options[:interval].to_i
    payload = options[:payload] ? options[:payload] : ( "%08d" % counter )
    t = Time.now
    print sended_message(counter, t, payload)
    
    #send ping
    conn.ping(payload)
  elsif frame[:type] == :goaway
    puts "\nRecieve GOAWAY(#{frame[:payload]})"
    puts statics_message(max, min, sum, counter) if options[:statics]
    options[:statics] == false #for not call in rescue...
  end
end


puts "==== PING #{uri} (interval: #{options[:interval]}sec)====\n"
payload = options[:payload] ? options[:payload] : ( "%08d" % counter )
t = Time.now
print sended_message(counter, t, payload)

conn.ping(payload)

while !sock.closed? && !sock.eof?
  data = sock.read_nonblock(1024)

  begin
    conn << data
  rescue SystemExit => err
    puts "\n==== #{options[:count]} frame sended ===="
    puts statics_message(max, min, sum, counter) if options[:statics]
    exit(0)
  rescue Exception => e
    puts "Exception: #{e}, #{e.message} - closing socket."
    puts statics_message(max, min, sum, counter) if options[:statics]
    exit(0)
    sock.close
  end
end
