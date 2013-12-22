require 'rubygems'
require 'bundler'
require 'sinatra'
require 'sinatra/cross_origin'
require 'json'
require 'thin'

Bundler.require

configure do
  enable :cross_origin
end

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
  property :studio_name, Text
  property :password, Text
  has n, :contacts
  property :created_at, DateTime
end

class Contact
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
  property :shoot_date, Text
  property :shoot_time, Text
  property :location, Text
  property :delivery_date, Text
  property :charges, Decimal
  property :notes, Text
  property :delivered, Boolean
  property :delivered_flag_date, Text
  belongs_to :contact
  property :created_at, DateTime
end

DataMapper.finalize
Photographer.auto_upgrade!
Contact.auto_upgrade!
Shoot.auto_upgrade!

post '/photographers' do
  content_type :json
  photographer = Photographer.create(params)
  photographer.to_json
end

post '/photographers/:id/contacts' do
  content_type :json
  photographer = Photographer.get(params[:id])
  contact = photographer.contacts.create(name: params[:name], phone: params[:phone], email: params[:email])
  contact.to_json
end

post '/contacts/:id/shoots' do
  content_type :json
  contact = Contact.get(params[:id])
  shoot = contact.shoots.create(shoot_type: params[:shoot_type], shoot_date: params[:shoot_date], shoot_time: params[:shoot_time],
                                location: params[:location], delivery_date: params[:delivery_date], charges: params[:charges],
                                notes: params[:notes])
  shoot.to_json
end

get '/contacts/:id/' do
  content_type :json
  contact = Contact.get(params[:id])
  contact.to_json
end

get '/shoots/:id/' do
  content_type :json
  shoot = Shoot.get(params[:id])
  {
      id: shoot.id,
      name: shoot.contact.name,
      email: shoot.contact.email,
      phone: shoot.contact.phone,
      shoot_type: shoot.shoot_type,
      shoot_date: Time.parse(shoot.shoot_date).strftime("%d-%b-%Y"),
      shoot_time: Time.parse(shoot.shoot_time).strftime("%I:%M %p"),
      location: shoot.location,
      delivery_date: Time.parse(shoot.delivery_date).strftime("%d-%b-%Y"),
      charges: shoot.charges,
      notes: shoot.notes,
      delivered: shoot.delivered
  }.to_json
end

get '/photographers/:id/shoots/all' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.contacts.each do |contact|
      contact.shoots.each do |shoot|
          formatted_shoots << {
              id: shoot.id,
              shoot_date: shoot.shoot_date,
              shoot_time: shoot.shoot_time,
              contact_name: contact.name,
              shoot_type: shoot.shoot_type
          }
      end
  end
  formatted_shoots.sort_by { |s| Date.parse(s[:shoot_date]) }.reverse.to_json
end

get '/photographers/:id/shoots/upcoming' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.contacts.each do |contact|
    contact.shoots.each do |shoot|
      next if Date.parse(shoot.shoot_date) < Time.now.to_date
      formatted_shoots << {
          id: shoot.id,
          shoot_date: shoot.shoot_date,
          shoot_time: shoot.shoot_time,
          contact_name: contact.name,
          shoot_type: shoot.shoot_type
      }
    end
  end
  formatted_shoots.sort_by { |s| Date.parse(s[:shoot_date]) }.reverse.to_json
end

get '/' do
  content_type :json
  @contacts = Contact.all(:order => [:id.desc])
  @contacts.to_json
end

delete '/shoots/:id' do
  content_type :json
  shoot = Shoot.get(params[:id])
  shoot.destroy
  {}.to_json
end