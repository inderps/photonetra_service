require 'rubygems'
require 'bundler'
require 'sinatra'
require 'json'
require 'thin'

Bundler.require

if ENV['VCAP_SERVICES']
  services = JSON.parse(ENV['VCAP_SERVICES'])
  postgresql_key = services.keys.select { |svc| svc =~ /postgresql/i }.first
  postgresql = services[postgresql_key].first['credentials']
  postgresql_conn = "postgres://"+postgresql['user']+":"+postgresql['password']+ \
    "@"+postgresql['host']+":"+postgresql['port'].to_s() +"/"+postgresql['name']
  DataMapper.setup(:default, postgresql_conn)
else
  DataMapper.setup(:default, "postgres://photonetra:photonetra@localhost:5432/photonetra")
end

class Client
  include DataMapper::Resource
  property :id, Serial
  property :name, Text
  property :phone, Text
  property :email, Text
  property :address, Text
  property :created_at, DateTime
end

DataMapper.finalize
Client.auto_upgrade!

get '/' do
  content_type :json
  @clients = Client.all(:order => [:id.desc])
  @clients.to_json
end