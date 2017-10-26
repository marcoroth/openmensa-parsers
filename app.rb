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

get '/parsers/svgroup/meta', provides: ['xml'] do
  nokogiri :index
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
