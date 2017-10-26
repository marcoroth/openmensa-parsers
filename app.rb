require 'sinatra'
require 'sinatra/reloader' if development?
require 'nokogiri'
require 'uri'
require 'open-uri'
require 'net/http'
require 'date'
require 'json'

get '/' do
  redirect to('/parsers/svgroup')
end

get '/parsers/svgroup' do
  erb :index
end

get '/parsers/svgroup/meta', provides: ['json'] do
  url = "http://mensa-fhnw.sv-restaurant.ch/de/menuplan/persrest-data.json"
  json = JSON.load(open(url))

  canteens = []

  json["items"].each do |i|
    begin
      uri = URI(i["link"])
      host = uri.host
      mensa_name = host.split(".")[0]

      canteens << [ mensa_name, "#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + mensa_name + "/meta" ]

    rescue
    end
  end
  canteens.to_json
end

get '/parsers/svgroup/:name' do
  nokogiri :canteen, locals: { mensa_name: params["name"] }
end

get '/parsers/svgroup/:name/meta' do
  nokogiri :meta, locals: { mensa_name: params["name"] }
end

get '/parsers/svgroup/:name/today' do
  nokogiri :canteen, locals: { mensa_name: params["name"], amount_days: 1 }
end
