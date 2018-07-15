require 'method_source'
require 'colorize'
require 'digest'
require 'fileutils'

require 'remote_ruby/compiler'
require 'remote_ruby/connection_adapter'
require 'remote_ruby/unmarshaler'
require 'remote_ruby/locals_extractor'
require 'remote_ruby/flavour'

module RemoteRuby
  class ExecutionContext
    def initialize(**params)
      add_flavours(params)
      @use_cache = params.delete(:use_cache) || false
      @save_cache = params.delete(:save_cache) || false
      @cache_dir = params.delete(:cache_dir) || File.join(Dir.pwd, 'cache')
      @out_stream = params.delete(:stdout) || $stdout
      @err_stream = params.delete(:stderr) || $stderr
      @adapter_klass = params.delete(:adapter) || ::RemoteRuby::SSHStdinAdapter
      @params = params

      FileUtils.mkdir_p(@cache_dir)
    end

    def execute(locals = nil, &block)
      if locals.nil?
        extractor =
          ::RemoteRuby::LocalsExtractor.new(block, ignore_types: self.class)
        locals = extractor.locals
      end

      result = execute_code(parse_block(block.source), **locals)

      locals.each do |key, _|
        if result[:locals].key?(key)
          block.binding.local_variable_set(key, result[:locals][key])
        end
      end

      result[:result]
    end

    # Quick and dirty solution
    # Will only work with well-formatted 'do' blocks now
    def parse_block(block_code)
      block_code.lines[1..-2].join
    end

    def context_hash(code_hash)
      Digest::MD5.hexdigest(self.class.name + adapter_klass.name.to_s + params.to_s + code_hash)
    end

    def cache_path(code_hash)
      hsh = context_hash(code_hash)
      File.join(cache_dir, hsh)
    end

    def cache_exists?(code_hash)
      hsh = cache_path(code_hash)
      File.exist?("#{hsh}.stdout") || File.exist?("#{hsh}.stderr")
    end

    def execute_code(ruby_code, client_locals = {})
      compiler = RemoteRuby::Compiler.new(
        ruby_code,
        client_locals: client_locals,
        ignore_types: self.class,
        flavours: flavours
      )

      code = compiler.compile

      res = nil
      locals = nil

      code_hash = compiler.code_hash

      adapter = adapter_klass.new(params)

      adapter =
        if use_cache && cache_exists?(code_hash)
          ::RemoteRuby::CacheAdapter.new(
            connection_name: adapter.connection_name,
            cache_path: cache_path(code_hash)
          )
        elsif save_cache
          ::RemoteRuby::CachingAdapter.new(
            adapter: adapter,
            cache_path: cache_path(code_hash)
          )
        else
          adapter
        end

      adapter.open do |stdin, stdout, stderr|
        stdin.write(code)
        stdin.close

        stdout_thread = Thread.new do
          until stdout.eof?
            line = stdout.readline

            if line.start_with?('%%%MARSHAL')
              unmarshaler = RemoteRuby::Unmarshaler.new
              locals = unmarshaler.unmarshal(stdout)
              res = locals[:__return_val__]
            else
              out_stream.puts "#{adapter.connection_name.green}>\t#{line}"
            end
          end
        end

        stderr_thread = Thread.new do
          until stderr.eof?
            line = stderr.readline
            err_stream.puts "#{adapter.connection_name.red}>\t#{line}"
          end
        end

        stdout_thread.join
        stderr_thread.join
      end

      { result: res, locals: locals }
    end

    private

    def add_flavours(params)
      @flavours = ::RemoteRuby::Flavour.build_flavours(params)
    end

    attr_reader :params, :adapter_klass, :use_cache, :save_cache, :cache_dir,
                :out_stream, :err_stream, :flavours
  end
end
