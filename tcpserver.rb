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
  socket = server.accept
  log.info("accepted...")
  pid = fork do
    log.info("pid is : #{Process.pid}")
    log.info("addr is : #{socket.addr}")
    # TODO: 別クラスにしたい
    thread = Thread.start(socket) do | socket |
      begin
        socket.each_line do | line |
          # this is received line buffer
          log.info(line.strip)
        end
      ensure
        log.info("thread will be destroyed")
      end
    end
    log.info("thread is: #{thread.inspect}")
    begin
      while buffer = gets
        # this is input line buffer
        log.info(buffer)
        socket.sendmsg(buffer)
        if buffer.chomp == "exit"
          break
        end
      end
    ensure
      socket.close
      thread.kill
      log.info("close")
    end
  end
  # 親では必ず直ぐに切断する
  socket.close


  # Thread.start(server.accept) do | socket |
  #   log.info("accepted...")
  #   while buffer = socket.gets
  #     log.info(buffer)
  #     if buffer.chomp == "exit"
  #       break
  #     end
  #   end
  #   socket.close
  # end

end

server.close