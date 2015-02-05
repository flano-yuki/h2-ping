#!/usr/bin/env ruby

require 'optparse'
require 'socket'
require 'openssl'
require 'http/2'
require 'uri'
DRAFT = 'h2-14'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ping.rb [options]"
  opts.on("-d", "--data [String]", "PING payload (8bytes)")     do |v| options[:payload] = v end
  opts.on("-n", "--interval [Integer]", "PING interval (sec)") do |v| options[:interval] = v end
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


counter = 100000000 #use for ping payload
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
    elapsed = (Time.now.usec / 1000.0).round - (t.usec / 1000.0).round
    print "Recieve ACK (#{frame[:payload]}) (#{elapsed}ms)"
    counter += 1
    sleep options[:interval].to_i
    payload = options[:payload] ? options[:payload] : counter.to_s.slice(1..9)
    t = Time.now
    print "\n#{t.strftime("%k:%M:%S")} Send PING (#{payload})... "
    conn.ping(payload)
  elsif frame[:type] == :goaway
    puts "\nRecieve GOAWAY(#{frame[:payload]})"
  end
end


puts "\n==== PING #{uri} (interval: #{options[:interval]}sec)===="
payload = options[:payload] ? options[:payload] : counter.to_s.slice(1..9)
t = Time.now
print "#{t.strftime("%k:%M:%S")} Send PING (#{payload})... "
conn.ping(payload)

while !sock.closed? && !sock.eof?
  data = sock.read_nonblock(1024)

  begin
    conn << data
  rescue Exception => e
    puts "Exception: #{e}, #{e.message} - closing socket."
    sock.close
  end
end
