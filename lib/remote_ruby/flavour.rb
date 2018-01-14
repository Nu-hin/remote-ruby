module RemoteRuby
  class Flavour
    def self.build_flavours(params = {})
      res = []

      {
        rails: RemoteRuby::RailsFlavour
      }.each do |name, klass|
        options = params.delete(name)

        if options
          res << klass.new(**options)
        end
      end

      res
    end

    def initialize(params: {})
    end

    def code_header; end
  end
end

require 'remote_ruby/flavour/rails_flavour'
