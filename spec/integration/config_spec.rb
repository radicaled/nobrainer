require 'spec_helper'

describe 'config' do
  context 'with a rails app' do
    before do
      define_class :SomeApp do
      end

      define_class :'SomeApp::Application' do
      end

      define_class :Rails do
        def self.application
          SomeApp::Application.new
        end

        def self.env
          'env'
        end
      end
    end

    after do
      ENV['RETHINKDB_URL'] = nil
      ENV['RETHINKDB_HOST'] = nil
      ENV['RETHINKDB_PORT'] = nil
      ENV['RETHINKDB_AUTH'] = nil
      ENV['RETHINKDB_DB'] = nil
    end

    it 'picks a default url' do
      ENV['RETHINKDB_URL'] = 'rethinkdb://l/db'
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://l/db'

      ENV['RETHINKDB_URL'] = nil
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://localhost/some_app_env'

      ENV['RETHINKDB_HOST'] = 'host'
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://host/some_app_env'

      ENV['RETHINKDB_PORT'] = '12345'
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://host:12345/some_app_env'

      ENV['RETHINKDB_AUTH'] = 'auth'
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://:auth@host:12345/some_app_env'

      ENV['RETHINKDB_DB'] = 'hello'
      NoBrainer::Config.configure { |c| c.reset! }
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://:auth@host:12345/hello'
    end
  end

  context 'when configuring the app_name and enviroment' do
    it 'sets the rethinkdb_url default' do
      NoBrainer.configure do |c|
        c.reset!
        c.app_name = :app
        c.environment = :test
      end
      NoBrainer::Config.rethinkdb_urls.first.should == 'rethinkdb://localhost/app_test'
    end
  end

  context 'when configuring the in dev mode' do
    it 'sets the the durability to soft' do
      NoBrainer.configure do |c|
        c.reset!
        c.app_name = :app
        c.environment = :development
      end
      NoBrainer::Config.durability.should == :soft

      NoBrainer.configure do |c|
        c.environment = :test
      end
      NoBrainer::Config.durability.should == :soft

      NoBrainer.configure do |c|
        c.environment = :other
      end
      NoBrainer::Config.durability.should == :hard

      NoBrainer.configure do |c|
        c.environment = :test
        c.durability = :hard
      end
      NoBrainer::Config.durability.should == :hard

      NoBrainer.configure do |c|
        c.environment = :test
      end
      NoBrainer::Config.durability.should == :hard

      NoBrainer.configure do |c|
        c.reset!
        c.app_name = :app
        c.environment = :test
      end
      NoBrainer::Config.durability.should == :soft
    end
  end

  context 'when configuring bad values' do
    context 'with durability' do
      it 'yells' do
        expect do
          NoBrainer.configure do |c|
            c.reset!
            c.durability = :blah
          end
        end.to raise_error(ArgumentError, "Invalid configuration for durability: blah. Valid values are: [:hard, :soft]")
      end
    end

    context 'with the url' do
      before { NoBrainer.logger.level = Logger::FATAL }
      it 'yells' do
        expect { NoBrainer.configure { |c| c.rethinkdb_url = 'xxx' }; NoBrainer.run { } }.to raise_error(/Invalid URI/)
        expect { NoBrainer.configure { |c| c.rethinkdb_url = 'blah://xxx/' }; NoBrainer.run { } }.to raise_error(/Invalid URI/)
        expect { NoBrainer.configure { |c| c.rethinkdb_url = 'rethinkdb://x/' }; NoBrainer.run { } }.to raise_error(/No database/)
      end
    end
  end
end
