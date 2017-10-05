require 'dry/equalizer'

module DbSchema
  class Configuration
    include Dry::Equalizer(:params)

    DEFAULT_VALUES = {
      adapter:     'postgres',
      host:        'localhost',
      port:        5432,
      database:    nil,
      user:        nil,
      password:    '',
      log_changes: true,
      dry_run:     false,
      post_check:  true
    }.freeze

    def initialize(params = {})
      @params = [
        DEFAULT_VALUES,
        Configuration.params_from_url(params[:url]),
        Utils.filter_by_keys(params, *DEFAULT_VALUES.keys)
      ].reduce(:merge)
    end

    def merge(new_params)
      Configuration.new(@params.merge(new_params))
    end

    [:adapter, :host, :port, :database, :user, :password].each do |param_name|
      define_method(param_name) do
        @params[param_name]
      end
    end

    def log_changes?
      @params[:log_changes]
    end

    def dry_run?
      @params[:dry_run]
    end

    def post_check_enabled?
      @params[:post_check]
    end

    class << self
      def params_from_url(url_string)
        return {} if url_string.nil?
        url = URI.parse(url_string)

        Utils.remove_nil_values(
          adapter:  url.scheme,
          host:     url.host,
          port:     url.port,
          database: url.path.sub(/\A\//, ''),
          user:     url.user,
          password: url.password
        )
      end
    end

  protected
    attr_reader :params
  end
end
