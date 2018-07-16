require 'remote_ruby/stream_cacher'

module RemoteRuby
  # An adapter decorator which extends the adapter passed in to its
  # initializer to cache stidin and stdout to local filesystem
  class CachingAdapter < ConnectionAdapter
    def initialize(cache_path:, adapter:)
      @cache_path = cache_path
      @adapter = adapter
    end

    def connection_name
      adapter.connection_name
    end

    def open(code)
      with_cache do |stdout_cache, stderr_cache|
        adapter.open(code) do |stdout, stderr|
          yield ::RemoteRuby::StreamCacher.new(stdout, stdout_cache),
          ::RemoteRuby::StreamCacher.new(stderr, stderr_cache)
        end
      end
    end

    private

    attr_reader :cache_path, :adapter

    def with_cache
      stderr_cache = File.open(stderr_file_path, 'w')
      stdout_cache = File.open(stdout_file_path, 'w')

      yield stdout_cache, stderr_cache
    ensure
      stdout_cache.close
      stderr_cache.close
    end

    def stdout_file_path
      "#{cache_path}.stdout"
    end

    def stderr_file_path
      "#{cache_path}.stderr"
    end
  end
end
