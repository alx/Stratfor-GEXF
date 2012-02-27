# encoding: utf-8
require 'rubygems'
require 'net/http'
require 'open-uri'
require 'builder'
require 'nokogiri'

class Grapher
  
  attr_reader :data, :xml

  def initialize
    @data = {:nodes => [], :edges => []}
    @xml = Builder::XmlMarkup.new(:ident => 1)
  end

  def parse_social(url)
    doc = Nokogiri::HTML(open(url))
    table = doc.css("table.cable")
    rows = table.css("tr")
    # p rows.size
    rows.each do |rows|
      if cells = rows.css("td")
        if cells[2]
          from = cells[2].inner_text.gsub("@stratfor.com", "")
          from = "anonymous" if from.empty?
          add_node(from)

          to = cells[3].inner_text.split(", ")
          to.each do |to|
            to.gsub!("@stratfor.com", "")
            add_node(to)
            add_edge(from, to)
          end
        end
      end
    end
  end

  def generate_gexf
    @xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
    @xml.gexf(:xmlns => "http://www.gexf.net/1.2draft", :version => "1.2") do
      @xml.meta(:lastmodifieddate => Time.now.strftime("%Y-%m-%d")) do
        @xml.creator "Tetalab"
        @xml.description "Stratfor"
      end
      @xml.graph(:mode => "static", :defaultedgetype => "directed") do
        @xml.nodes(:count => @data[:nodes].size) do
          @data[:nodes].each do |node|
            @xml.node :id => node[:id], :label => node[:label]
            if node[:parents]
              @xml.parents do
                node[:parents].each do |parent|
                  @xml.parent :for => parent
                end
              end
            end
          end
        end
        @xml.edges(:count => @data[:edges].size) do
          @data[:edges].each do |edge|
            @xml.edge :id => edge[:id], :source => edge[:source], :target => edge[:target], :weight => edge[:weight]
          end
        end
      end
    end
    return @xml.target!
  end

  private

  def add_node(node)
    @data[:nodes] << {:id => node, :label => node} if data[:nodes].select{|node| node[:id] == node}.empty?
  end
  
  def add_edge(node1, node2)
    if edge = @data[:edges].select{|edge| edge[:id] == "#{node1}-#{node2}"}.pop
      edge[:weight] += 1
    else
      @data[:edges] << {:id => "#{node1}-#{node2}", :source => node1, :target => node2, :weight => 1}
    end
  end
end

graph = Grapher.new
graph.parse_social("http://www.wikileaks.org/gifiles/releasedate/2012-02-27.html")
#p graph.data

File.open('stratfor_social.gexf', "w") do |f|
  f.write graph.generate_gexf
end
