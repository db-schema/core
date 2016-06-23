module DbSchema
  class Configuration
    attr_reader :adapter, :host, :port, :database, :user, :password

    def initialize(adapter: 'postgres', host: 'localhost', port: 5432, database:, user: nil, password: '', debug: false)
      @adapter  = adapter
      @host     = host
      @port     = port
      @database = database
      @user     = user
      @password = password
      @debug    = debug
    end

    def debug?
      @debug
    end
  end
end
