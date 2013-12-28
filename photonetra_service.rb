require 'rubygems'
require 'bundler'
require 'active_support/all'
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
  property :website, Text
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
  property :shoot_time_from, Text
  property :shoot_time_to, Text
  property :location, Text
  property :delivery_date, Text
  property :charges, Decimal
  property :notes, Text
  property :delivered, Boolean
  property :delivered_flag_date, Text
  belongs_to :contact
  has n, :payments
  property :created_at, DateTime
end

class Payment
  include DataMapper::Resource
  property :id, Serial
  property :payment_date, Text
  property :amount, Decimal
  property :comment, Text
  belongs_to :shoot
  property :created_at, DateTime
end

DataMapper.finalize
Photographer.auto_upgrade!
Contact.auto_upgrade!
Shoot.auto_upgrade!
Payment.auto_upgrade!

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
  shoot = contact.shoots.create(shoot_type: params[:shoot_type], shoot_date: params[:shoot_date], shoot_time_from: params[:shoot_time_from],
                                shoot_time_to: params[:shoot_time_to], location: params[:location], delivery_date: params[:delivery_date], charges: params[:charges],
                                notes: params[:notes])
  shoot.to_json
end

post '/contacts/:id/' do
  content_type :json
  contact = Contact.get(params[:id])
  contact.name = params[:name] if params[:name]
  contact.phone = params[:phone] if params[:phone]
  contact.email = params[:email] if params[:email]
  contact.save
  contact.to_json
end

post '/shoots/:id/payments' do
  content_type :json
  shoot = Shoot.get(params[:id])
  shoot.payments.create(payment_date: params[:payment_date], amount: params[:amount], comment: params[:comment])
  {
    shoot_id: shoot.id
  }.to_json
end

post '/shoots/:id/mark_delivery' do
  content_type :json
  shoot = Shoot.get(params[:id])
  #shoot.delivered = true
  #shoot.delivered_flag_date = params[:delivered_flag_date]
  #shoot.save
  {
      id: shoot.id,
      name: shoot.contact.name,
      email: shoot.contact.email,
      phone: shoot.contact.phone,
      shoot_type: shoot.shoot_type,
      shoot_date: Time.parse(shoot.shoot_date).strftime("%b #{Time.parse(shoot.shoot_date).day.ordinalize}"),
      shoot_unformatted_date: Time.parse(shoot.shoot_date).strftime("%Y-%m-%d"),
      shoot_time_from: shoot.shoot_time_from,
      shoot_time_to: shoot.shoot_time_to,
      location: shoot.location,
      delivery_date: Time.parse(shoot.delivery_date).strftime("%d-%b-%Y"),
      charges: shoot.charges,
      notes: shoot.notes,
      delivered: shoot.delivered
  }.to_json
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
      shoot_date: Time.parse(shoot.shoot_date).strftime("%b #{Time.parse(shoot.shoot_date).day.ordinalize}"),
      shoot_unformatted_date: Time.parse(shoot.shoot_date).strftime("%Y-%m-%d"),
      shoot_time_from: shoot.shoot_time_from,
      shoot_time_to: shoot.shoot_time_to,
      location: shoot.location,
      delivery_date: Time.parse(shoot.delivery_date).strftime("%d-%b-%Y"),
      charges: shoot.charges,
      notes: shoot.notes,
      delivered: shoot.delivered
  }.to_json
end

get '/photographers/:id/shoots' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.contacts.each do |contact|
    contact.shoots.each do |shoot|
      next if params[:filter] == "upcoming" && Date.parse(shoot.shoot_date) < Time.now.to_date
      formatted_shoots << {
          id: shoot.id,
          shoot_date: Time.parse(shoot.shoot_date).strftime("%b #{Time.parse(shoot.shoot_date).day.ordinalize}, %Y"),
          #shoot_time: Time.parse(shoot.shoot_time).strftime("%I:%M %p"),
          shoot_time_from: shoot.shoot_time_from,
          shoot_time_to: shoot.shoot_time_to,
          contact_name: contact.name,
          shoot_type: shoot.shoot_type
      }
    end
  end
  formatted_shoots.sort{|a,b| [Time.parse(b[:shoot_date]), Time.parse(a[:shoot_date]+ " " + a[:shoot_time_from])] <=> [Time.parse(a[:shoot_date]), Time.parse(b[:shoot_date]+ " " + b[:shoot_time_from])] }.to_json
end

get '/photographers/:id/contacts' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_contacts = []
  photographer.contacts.each do |contact|
    formatted_contacts << {
        id: contact.id,
        name: contact.name,
        phone: contact.phone
    }
  end
  formatted_contacts.sort_by { |c| c[:name] }.to_json
end

get '/photographers/:id/pending_deliveries' do
  content_type :json
  photographer = Photographer.get(params[:id])
  formatted_shoots = []
  photographer.contacts.each do |contact|
    contact.shoots.each do |shoot|
      next if Date.parse(shoot.delivery_date) < Time.now.to_date
      formatted_shoots << {
          id: shoot.id,
          shoot_date: Time.parse(shoot.shoot_date).strftime("%b #{Time.parse(shoot.shoot_date).day.ordinalize}, %Y"),
          delivery_date: Time.parse(shoot.delivery_date).strftime("%b #{Time.parse(shoot.delivery_date).day.ordinalize}, %Y"),
          contact_name: contact.name,
          shoot_type: shoot.shoot_type
      }
    end
  end
  formatted_shoots.sort_by {|s| Time.parse(s[:delivery_date])}.to_json
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