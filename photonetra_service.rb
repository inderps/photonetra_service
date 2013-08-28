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

class Photographer
  include DataMapper::Resource
  property :id, Serial
  property :name, Text
  property :phone, Text
  property :email, Text
  property :company_name, Text
  has n, :clients
  property :created_at, DateTime
end

class Client
  include DataMapper::Resource
  property :id, Serial
  property :name, Text
  property :phone, Text
  property :email, Text
  property :address, Text
  belongs_to :photographer
  has n, :shoots
  property :created_at, DateTime
end

class Shoot
  include DataMapper::Resource
  property :id, Serial
  property :shoot_type, Text
  property :shoot_date, DateTime
  property :location, Text
  property :delivery_date, Date
  property :charges, Float
  property :notes, Text
  property :delivered, Boolean
  property :delivered_flag_date, DateTime
  belongs_to :client
  property :created_at, DateTime
end

DataMapper.finalize
Photographer.auto_upgrade!
Client.auto_upgrade!
Shoot.auto_upgrade!

post '/photographers' do
  content_type :json
  photographer = Photographer.create(params)
  photographer.to_json
end

post '/photographers/:id/clients' do
  content_type :json
  photographer = Photographer.get(params[:id])
  client = photographer.clients.create(params[:client])
  client.to_json
end

post '/clients/:id/shoots' do
  content_type :json
  client = Client.get(params[:id])
  shoot = client.shoots.create(params[:shoot])
  shoot.to_json
end

get '/photographers/:id/shoots/all' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.clients.each do |client|
      client.shoots.each do |shoot|
          formatted_shoots << {
              id: shoot.id,
              shoot_date: shoot.shoot_date,
              client_name: client.name,
              shoot_type: shoot.shoot_type
          }
      end
  end
  formatted_shoots.sort_by { |s| s[:shoot_date] }.reverse.to_json
end

get '/photographers/:id/shoots/upcoming' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.clients.each do |client|
    client.shoots.each do |shoot|
      next if shoot.shoot_date < DateTime.now
      formatted_shoots << {
          id: shoot.id,
          shoot_date: shoot.shoot_date,
          client_name: client.name,
          shoot_type: shoot.shoot_type
      }
    end
  end
  formatted_shoots.to_json
end

get '/' do
  content_type :json
  @clients = Client.all(:order => [:id.desc])
  @clients.to_json
end

def shoots_by_photographer

end