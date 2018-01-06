require 'base64'
require 'digest'

module RemoteRuby
  class Compiler
    def initialize(ruby_code, client_locals = {})
      @ruby_code = ruby_code
      @client_locals = client_locals
    end

    def code_hash
      @code_hash = Digest::SHA256.hexdigest(ruby_code.to_s + client_locals.to_s)
    end

    def compile
      client_locals_base64 = {}

      client_locals.each do |name, data|
        begin
          bin_data = Marshal.dump(data)
          base64_data = Base64.strict_encode64(bin_data)
          client_locals_base64[name] = base64_data
        rescue TypeError => e
          warn "Cannot send variable #{name}: #{e.message}"
        end
      end

      template_file = File.expand_path('../code_templates/compiler/main.rb.erb', __FILE__)
      template = ERB.new(File.read(template_file))
      template.result(binding)
    end

    private

    attr_reader :ruby_code, :client_locals
  end
end
