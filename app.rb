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

get '/parsers/svgroup/:name', provides: ['xml'] do

  mensa_name = params["name"]

  url = "http://#{mensa_name}.sv-restaurant.ch/de/menuplan/"
  doc = Nokogiri::HTML(open(url))

  builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
    xml.openmensa(version: "2.1", xmlns: "http://openmensa.org/open-mensa-v2", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation": "http://openmensa.org/open-mensa-v2 http://openmensa.org/open-mensa-v2.xsd") {
      xml.version("5.04-4")
      xml.canteen {
        counter = 0

        doc.css(".menu-plan-tabs .menu-plan-grid").each do |day|

          date_string = doc.css(".day-nav .date")[counter].content + Date.today.year.to_s
          date = Date.strptime(date_string, "%d.%m.%Y")
          counter += 1

          xml.day(date: date){

            day.css('.menu-item').each do |item|

              meal = item.css(".menu-title").first.content
              prices = item.css(".price")
              description = item.css(".menu-description").first.content.gsub("\n\n", "\n").gsub("\n", " - ")

              if description.length == 0
                description = "Keine Beschreibung"
              end

              price_employees = 0.0
              price_others = 0.0

              prices.each do |p|
                if p.css("span").last.content == "INT"
                  price_employees = p.css("span").first.content
                end

                if p.css("span").last.content == "EXT"
                  price_others = p.css("span").first.content
                end
              end

              xml.category(name: "Gericht") {
                xml.meal{
                  xml.name(meal)
                  xml.note(description[0..249])
                  unless price_employees == 0.0
                    xml.price(price_employees, role: "employee")
                  end
                  unless price_others == 0.0
                    xml.price(price_others, role: "other")
                  end
                }
              }
            end
          }
        end
      }
    }
  end

  builder.to_xml
end

get '/parsers/svgroup/:name/meta', provides: ['xml'] do
  mensa_name = params["name"]

  url = "http://mensa-fhnw.sv-restaurant.ch/de/menuplan/persrest-data.json"
  json = JSON.load(open(url))

  mensa_url = "http://#{mensa_name}.sv-restaurant.ch"
  menuplan_url = mensa_url + "/de/menuplan/"
  doc = Nokogiri::HTML(open(menuplan_url))

  week_days = [
    { name: :sunday, de: "Sonntag", fr: "dimanche" },
    { name: :monday, de: "Montag", fr: "lundi" },
    { name: :tuesday, de: "Dienstag", fr: "mardi" },
    { name: :wednesday, de: "Mittwoch", fr: "mercredi" },
    { name: :thursday, de: "Donnerstag", fr: "jeudi" },
    { name: :friday, de: "Freitag", fr: "vendredi" },
    { name: :saturday, de: "Samstag", fr: "samedi" }
  ]

  opening_hours = {
    monday: { times: "true", attribute: "closed" },
    tuesday: { times: "true", attribute: "closed" },
    wednesday: { times: "true", attribute: "closed" },
    thursday: { times: "true", attribute: "closed" },
    friday: { times: "true", attribute: "closed" },
    saturday: { times: "true", attribute: "closed" },
    sunday: { times: "true", attribute: "closed" }
  }

  # opening_hours_el = doc.css(".opening-hours p")
  #
  # opening_hours_el.each do |oh|
  #   days = oh.css("strong").first.content.split("- ")
  #   hours = oh.content.gsub(oh.css("strong").first.content, "").strip!.gsub!(" Uhr", "").split("-")
  #
  #   first_day = week_days.select{ |wd| wd[:de] == days.first || wd[:fr] == days.first }.first
  #   last_day = week_days.select{ |wd| wd[:de] == days.last || wd[:fr] == days.last}.first
  #
  #   unless first_day.nil? && last_day.nil?
  #     week_days[week_days.index(first_day)..week_days.index(last_day)].each do |d|
  #       opening_hours[d[:name]][:times] = hours.join("-")
  #       opening_hours[d[:name]][:attribute] = "open"
  #     end
  #   end
  # end

  name = ""
  address = ""
  city = ""
  latitude = ""
  longitude = ""
  availability = ""

  json["items"].each do |i|

    if i["link"] == mensa_url.gsub!("//", "\/\/")
      name = i["name"]
      address = i["address"]
      latitude = i["lat"]
      longitude = i["lng"]

      split = i["address"].split(" ")
      city = split.last

      unless city.nil?
        if city.length <= 2 || city.include?("(")
          city = split[(split.size-2)..split.size].join(" ")
        end
      end

      url = URI("http://www.sv-restaurant.ch/de/personalrestaurants/restaurant-suche/?type=8700")
      http = Net::HTTP.new(url.host)
      request = Net::HTTP::Post.new(url)
      request.body = "searchfield=#{URI::encode(name)}"
      response = http.request(request).read_body

      availability = response.include?('\"type\":\"\\\\u00f6ffentlich') ? "public" : "restricted"

    end
  end

  builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
    xml.openmensa(version: "2.1", xmlns: "http://openmensa.org/open-mensa-v2", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation": "http://openmensa.org/open-mensa-v2 http://openmensa.org/open-mensa-v2.xsd") {
      xml.version("5.04-4")
      xml.canteen {
        xml.name(name)
        xml.address(address)
        xml.city(city)
        xml.phone("")
        xml.location("", latitude: latitude, longitude: longitude)
        xml.availability(availability)
        xml.times(type: "opening") {
          opening_hours.each do |oh|
            eval("xml.#{oh.first}(#{oh.last[:attribute]}: '#{oh.last[:times]}')")
          end
        }
        xml.feed(name: "today", priority: "0"){
          xml.schedule(dayOfMonth: "*", dayOfWeek: "*", hour: "8-14", retry: "30 1")
          xml.url("#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + mensa_name + "/today")
          xml.source(mensa_url)
        }
        xml.feed(name: "full", priority: "1"){
          xml.schedule(dayOfMonth: "*", dayOfWeek: "1", hour: "8", retry: "60 5 1440")
          xml.url("#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + mensa_name)
          xml.source(mensa_url)
        }
      }
    }

  end

  builder.to_xml
end

get '/parsers/svgroup/:name/today' do
  "today feed is not implemented yet"\
  "<br><br>"\
  "=> <a href='/parsers/svgroup/#{params[:name]}'>Take a look at the full feed instead</a>"
end
