require "socket"
require "pry"

server = TCPServer.open(8001)

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
  puts "waiting..."
  socket = server.accept
  puts "accepted..."
  pid = fork do
    puts "pid is : #{Process.pid}"
    # TODO: 別クラスにしたい
    thread = Thread.start(socket) do | socket |
      begin
        socket.each_line do | line |
          # this is received line buffer
          puts line
        end
      ensure
        puts "thread will be destroyed"
      end
    end
    puts "thread is: #{thread.inspect}"
    begin
      while buffer = gets
        # this is input line buffer
        puts buffer
        socket.sendmsg(buffer)
        if buffer.chomp == "exit"
          break
        end
      end
    ensure
      socket.close
      thread.kill
      puts "close"
    end
  end
  # 親では必ず直ぐに切断する
  socket.close


  # Thread.start(server.accept) do | socket |
  #   puts "accepted..."
  #   while buffer = socket.gets
  #     puts buffer
  #     if buffer.chomp == "exit"
  #       break
  #     end
  #   end
  #   socket.close
  # end

end

server.close