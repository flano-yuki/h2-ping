# h2-ping
Send HTTP/2 PING Frame

## Description
This script sends HTTP/2 PING Frame repeatedly.

## Requirement
This script use http-2 gem.
```
gem install http-2
```

## demo
spcify http or https url.
```
$ ./ping.rb http://localhost/

==== PING http://localhost/ (interval: 5sec)====
   0. 8:06:52 Send PING (00000000)... Recieve ACK (00000000) (11ms)
   1. 8:06:57 Send PING (00000001)... Recieve ACK (00000001) (16ms)
   2. 8:07:02 Send PING (00000002)... Recieve ACK (00000002) (7ms)
   3. 8:07:07 Send PING (00000003)... Recieve ACK (00000003) (6ms)
   4. 8:07:12 Send PING (00000004)... Recieve ACK (00000004) (9ms)
```

## options
```
Usage: ping.rb [options]
    -d, --data [String]              PING payload (8bytes)
    -i, --interval [Integer]         PING interval (sec)
    -c, --count [Integer]            number of send frame
    -v, --verbose                    show all frame info
```

## acknowledgment
Examle of http-2 gem has become a great help.
thkanks!!
