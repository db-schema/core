require 'dry/equalizer'

module DbSchema
  class Configuration
    include Dry::Equalizer(:params)

    DEFAULT_PARAMS = {
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

    def initialize(params = DEFAULT_PARAMS)
      @params = params
    end

    def merge(new_params)
      params = [
        @params,
        Configuration.params_from_url(new_params[:url]),
        Utils.filter_by_keys(new_params, *DEFAULT_PARAMS.keys)
      ].reduce(:merge)

      Configuration.new(params)
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
