require "logger"
require "socket"
require "pry"

server = TCPServer.open(8001)
log = Logger.new(STDOUT)

Signal.trap(:SIGCHLD) do |sig|
  puts "interrupted by signal #{sig} at #{caller[1]}"
  # 複数の子プロセスの終了に対して1つの SIGCHLD しか届かない
  # 場合があるのでループさせる必要があります
  begin
    while Process.waitpid(-1, Process::WNOHANG|Process::WUNTRACED)
      case
      when $?.signaled?
        puts "   child #{$?.pid} was killed by signal #{$?.termsig}"
        if $?.coredump?
          puts "   child #{$?.pid} dumped core."
        end
      when $?.stopped?
        puts "   child #{$?.pid} was stopped by signal #{$?.stopsig}"
      when $?.exited?
        puts "   child #{$?.pid} exited normally. status=#{$?.exitstatus}"
      else
        p "unknown status %#x" % $?.to_i
      end
    end
  rescue Errno::ECHILD => e
    puts e
  end
end

while true
  log.info("waiting...")
  bash_socket = server.accept
  log.info("accepted...")
  pid = fork do
    log.info("pid is : #{Process.pid}")
    log.info("addr is : #{bash_socket.addr}")
    sock_name = "server_#{Process.pid}.sock"
    log.info("sock_name is: #{sock_name}")

    begin
      sock_thread = Thread.new do
        UNIXServer.open(sock_name) do | userver |
          log.info(userver)
          log.info("unix domain socket server waiting...")
          usock = userver.accept
          log.info(usock)

          # connect unix socket to remote
          usock.send_io bash_socket
          rio = usock.recv_io
          begin
            while buffer = rio.gets
              # this is input line buffer
              log.info(buffer.strip)
              bash_socket.sendmsg(buffer)
              if buffer.chomp == "exit"
                usock.write(buffer)
                break
              end
            end
          rescue Errno::EPIPE => e
            log.error(e)
            break
          end
        end
        File.unlink(sock_name)
      end
      sock_thread.join
    ensure
      bash_socket.close
      log.info("close")
    end

  end
  # 親では必ず直ぐに切断する
  bash_socket.close


  # Thread.start(server.accept) do | bash_socket |
  #   log.info("accepted...")
  #   while buffer = bash_socket.gets
  #     log.info(buffer)
  #     if buffer.chomp == "exit"
  #       break
  #     end
  #   end
  #   bash_socket.close
  # end

end

server.close