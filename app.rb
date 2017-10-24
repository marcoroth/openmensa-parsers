require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'date'
require 'json'

get '/' do
  redirect to('/parsers/svgroup')
end

get '/parsers/svgroup' do

  url = "http://mensa-fhnw.sv-restaurant.ch/de/menuplan/persrest-data.json"

  json = JSON.load(open(url))

  output = "<h1>SV-Group Mensa</h1>"
  output += "<p><b>#{json["items"].count}</b> Einträge</p>"

  json["items"].each do |i|
    mensa_name = i["name"]
    mensa_url = i["link"]

    begin
      uri = URI(mensa_url)
      host = uri.host

      unless host.nil?
        mensa_xml_url = "#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + host.split(".")[0]
        output += "<a href='#{mensa_xml_url}'>#{mensa_name}</a> <a href='#{mensa_xml_url}/meta'>Meta</a><br>"
      end
    rescue URI::InvalidURIError
      puts "Fehler"
    end
  end

  output
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

  url = "http://#{mensa_name}.sv-restaurant.ch"
  doc = Nokogiri::HTML(open(url + "/de/menuplan/"))

  name = ""
  address = ""
  city = ""
  phone = ""
  latitude = ""
  longitude = ""

  json["items"].each do |i|

    if i["link"] == url.gsub!("//", "\/\/")
      name = i["name"]
      address = i["address"]
      latitude = i["lat"]
      longitude = i["lng"]
    end
  end



  builder = Nokogiri::XML::Builder.new(encoding: "utf-8") do |xml|
    xml.openmensa(version: "2.1", xmlns: "http://openmensa.org/open-mensa-v2", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation": "http://openmensa.org/open-mensa-v2 http://openmensa.org/open-mensa-v2.xsd") {
      xml.version("5.04-4")
      xml.canteen {
        xml.name(name)
        xml.address(address)
        xml.city("")
        xml.phone("")
        xml.location("", latitude: latitude, longitude: longitude)
        xml.availability("")
        xml.times(type: "opening") {
          xml.monday(open: "11:00-14:00")
          xml.tuesday(open: "11:00-14:00")
          xml.wednesday(open: "11:00-14:00")
          xml.thursday(open: "11:00-14:00")
          xml.friday(open: "11:00-14:00")
          xml.saturday(open: "11:00-14:00")
          xml.sunday(closed: "true")
        }
        xml.feed(name: "today", priority: "0"){
          xml.schedule(dayOfMonth: "*", dayOfWeek: "*", hour: "8-14", retry: "30 1")
          xml.url("#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + mensa_name + "/today")
          xml.source(url)
        }
        xml.feed(name: "full", priority: "1"){
          xml.schedule(dayOfMonth: "*", dayOfWeek: "1", hour: "8", retry: "60 5 1440")
          xml.url("#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/" + mensa_name)
          xml.source(url)
        }
      }
    }

  end


  builder.to_xml
end
