module DbSchema
  class Configuration
    attr_reader :adapter, :host, :port, :database, :user, :password

    def initialize(adapter: 'postgres', host: 'localhost', port: 5432, database:, user: nil, password: '', debug: false, post_check: true)
      @adapter    = adapter
      @host       = host
      @port       = port
      @database   = database
      @user       = user
      @password   = password
      @debug      = debug
      @post_check = post_check
    end

    def debug?
      @debug
    end

    def post_check_enabled?
      @post_check
    end
  end
end
