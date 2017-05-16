require 'socket'
require 'logger'

log = Logger.new(STDOUT)
sock = UNIXSocket.new ARGV.first

sock.send_io STDIN
bash_out = sock.recv_io

while buffer = bash_out.gets
  # this is input line buffer
  log.info(buffer.strip)
  if buffer.chomp == "exit"
    break
  end
end

log.info("end")