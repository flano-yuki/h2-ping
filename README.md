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
23:00:49 Send PING (00000000)... Recieve ACK (00000000) (10ms)
23:00:54 Send PING (00000001)... Recieve ACK (00000001) (5ms)
23:00:59 Send PING (00000002)... Recieve ACK (00000002) (5ms)
23:01:04 Send PING (00000003)... Recieve ACK (00000003) (4ms)
23:01:09 Send PING (00000004)... Recieve ACK (00000004) (5ms)
```

## options
```
Usage: ping.rb [options]
    -d, --data [String]              PING payload (8bytes)
    -n, --interval [Integer]         PING interval (sec)
    -v, --verbose                    show all frame info
```

## acknowledgment
Examle of http-2 gem has become a great help.
thkanks!!
