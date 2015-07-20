require 'rethinkdb'

class NoBrainer::Connection
  attr_accessor :uri, :parsed_uri

  def initialize(uri)
    self.uri = uri
    parsed_uri # just to raise an exception if there is a problem.
  end

  def parsed_uri
    @parsed_uri ||= begin
      require 'uri'
      uri = URI.parse(self.uri)

      if uri.scheme != 'rethinkdb'
        raise NoBrainer::Error::Connection,
          "Invalid URI. Expecting something like rethinkdb://host:port/database. Got #{uri}"
      end

      { :auth_key => uri.password,
        :host     => uri.host,
        :port     => uri.port || 28015,
        :db       => uri.path.gsub(/^\//, ''),
      }.tap { |result| raise "No database specified in #{uri}" unless result[:db].present? }
    end
  end

  def raw
    @raw ||= RethinkDB::Connection.new(parsed_uri)
  end

  delegate :reconnect, :close, :run, :to => :raw
  alias_method :connect, :raw
  alias_method :disconnect, :close

  def default_db
    parsed_uri[:db]
  end

  def current_db
    NoBrainer.current_run_options.try(:[], :db) || default_db
  end

  def drop!
    NoBrainer.run { |r| r.db_drop(current_db) }
  end

  # Note that truncating each table (purge!) is much faster than dropping the database (drop!)
  def purge!
    NoBrainer.run { |r| r.table_list }.each do |table_name|
      # keeping the index meta store because indexes are not going away when purging
      next if table_name == NoBrainer::Document::Index::MetaStore.table_name
      NoBrainer.run { |r| r.table(table_name).delete }
    end
    true
  end
end
