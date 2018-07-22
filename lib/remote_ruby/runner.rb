module RemoteRuby
  # Runner class is responsible for running a prepared Ruby code with given
  # connection adapter, reading output and unmarshalling result and local
  # variables values.
  class Runner
    def initialize(code:, adapter:, out_stream: $stdout, err_stream: $stderr)
      @code = code
      @adapter = adapter
      @out_stream = out_stream
      @err_stream = err_stream
    end

    def run
      locals = nil

      adapter.open(code) do |stdout, stderr|
        stdout_thread = Thread.new do
          locals = read_out_stream(stdout)
        end

        stderr_thread = Thread.new do
          read_err_stream(stderr)
        end

        stdout_thread.join
        stderr_thread.join
      end

      { result: locals[:__return_val__], locals: locals }
    end

    private

    def read_out_stream(stdout)
      until stdout.eof?
        line = stdout.readline

        if line.start_with?('%%%MARSHAL')
          locals = unmarshal(stdout)
        else
          out_stream.puts "#{adapter.connection_name.green}>\t#{line}"
        end
      end

      locals
    end

    def read_err_stream(stderr)
      until stderr.eof?
        line = stderr.readline
        err_stream.puts "#{adapter.connection_name.red}>\t#{line}"
      end
    end

    def unmarshal(stdout)
      unmarshaler = RemoteRuby::Unmarshaler.new(stdout)
      unmarshaler.unmarshal
    end

    attr_reader :code, :adapter, :out_stream, :err_stream
  end
end
