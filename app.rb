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
        mensa_xml_url = "#{request.scheme}://" + request.host + ":" + request.port.to_s + "/parsers/svgroup/"+ host.split(".")[0]
        output += "<a href='#{mensa_xml_url}'>#{mensa_name}</a><br>"
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

  File.write("openmensa.xml", builder.to_xml)

  builder.to_xml
end
