# Ikariam
require 'hpricot'

module Ikariam #:nodoc:
  
  class Base
    attr_accessor :game_server
    attr_accessor :user_agent
    
    attr_accessor :http
    attr_accessor :ik_cookie
    
    def headers(referer, need_cookie = true)
      if need_cookie
        @headers = {
          'Cookie' => self.ik_cookie,
          'Referer' => referer,
          'Content-Type' => 'application/x-www-form-urlencoded',
          'User-Agent' => self.user_agent}
      else
        @headers = {
          'Referer' => referer,
          'Content-Type' => 'application/x-www-form-urlencoded',
          'User-Agent' => self.user_agent}
      end
    end
    
    def post(path, posted_data)
      resp, data = @http.post2(path, posted_data, @headers)
      resp
    end
    
    def get2(uri)
      resp, data = @http.get2(uri, @headers)
      resp
    end
    
    def initialize(server ="", agent="")
      # thumbnail = Thumbnail.new()
      self.game_server = 's9.ru.ikariam.com' if server.blank?
      
      # See: http://snippets.dzone.com/posts/show/788      
      # @http.use_ssl = true
      self.http = Net::HTTP.new(self.game_server)
      
      if agent.blank?
        self.user_agent = "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.1.7) Gecko/20091221 Firefox/3.5.7 GTB7.1"
      end
    end
    
  end
  
  class Accaunt < Base
    attr_accessor :login
    attr_accessor :email
    attr_accessor :password
    
    attr_accessor :capital
    
    attr_accessor :gold
    
    
    def create
      path = '/index.php?action=newPlayer'
      data = "universe=#{ERB::Util.url_encode(self.game_server)}"+
             "&name=#{ERB::Util.url_encode(self.login)}&password=#{ERB::Util.url_encode(self.password)}"+
             "&email=#{ERB::Util.url_encode(self.email)}"
      data = "function=createAvatar&agb=on&" + data;
      headers("http://#{self.game_server}/register.php", false)
      
      resp = post(path, data)
      
      puts("created login #{@login} with password #{@password}")
      return true
    end
    
    
    
    def login_to_game
      login_path = '/index.php'
      
      # POST request -> logging in
      data = "universe=#{self.game_server}&name=#{self.login}&password=#{self.password}"
      data = 'action=loginAvatar&function=login&' + data;
      headers("http://#{self.game_server}/index.php", false)
      
      post_login(login_path, data)
      puts "login as: " + @login + " / " + @password
      true
    end
    
    def initialize()
      super
      self.capital = City.new(self)
    end
    
    def research(knowledge)
      path = '/index.php'
      data = "view=researchAdvisor"
      headers("http://#{self.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
      
      resp = get2(path + '?' + data)
      
      doc = Hpricot(resp.body)
      # get link
       (doc/"div[@class='researchInfo']").each do |elem|
        if elem.at("h4").inner_text.strip == knowledge
          div = Hpricot(elem.to_s)
          link = (div/"a[@class='button build']")[0].attributes['href']
          puts "Research " + knowledge
          return get2(path + link)
        end
      end
      puts "Reseach '#{knowledge}' not found. Already learned?"
      # [0].attributes['href']
    end
    
    private
    
    def post_login(path, posted_data)
      resp, data = @http.post2(path, posted_data, @headers)
      
      # @cookie = resp.response['set-cookie']
      # cookie = resp.response['set-cookie'].split('; ')[0]
      # php session id
      # @php_sess = cookie.split("=").last
      self.ik_cookie = resp.response['set-cookie'].split(', ').last
      
      doc = Hpricot(resp.body)
      
      # (5 (44) )
      # @population = (doc/"div[@id='cityResources']/ul/li[@class='population']/span[@id='value_inhabitants']").text
      self.capital.population_count = (doc/"span[@id='value_inhabitants']").text
      self.capital.game_actions = (doc/"span[@id='value_maxActionPoints']").text
      
      # resurses
      # @wood = (doc/"div[@id='cityResources']/ul/li[@class='wood']/span[@id='value_wood']").text
      
      self.capital.wood = (doc/"span[@id='value_wood']").text
      self.capital.wine = (doc/"span[@id='value_wine']").text
      self.capital.marble = (doc/"span[@id='value_marble']").text
      self.capital.glass = (doc/"span[@id='value_glass']").text
      self.capital.sulfur = (doc/"span[@id='value_sulfur']").text
      
      self.gold = (doc/"span[@id='value_gold']").text
      
      self.capital.city_id = (doc/"li[@class='viewCity']/a")[0].attributes['href'].split('=').last
      self.capital.island_id = (doc/"li[@class='viewIsland']/a")[0].attributes['href'].split('=').last
      
      self.capital.island_res = (doc/"option[@class='coords']")[0].attributes['title']

      self.capital.island_name = (doc/"div[@id='breadcrumbs']/a[@class='island']").text
      
      have_diplomacy_event = (doc/"li[@id='advDiplomacy']/a")[0].attributes['class'] == 'normalactive'
      
      build_time = (doc/"span[@id='cityCountdown']").text
      
      puts "logged to capital: #{self.capital.city_id} "+
           "on island: #{self.capital.island_name}, #{self.capital.island_res}, Ресы: "+
           "wood: #{self.capital.wood}, gold: #{self.gold} "
      puts "Population: #{self.capital.population_count}"
      puts "Build time: #{build_time}"
      if have_diplomacy_event
        puts "Forum msg: #{self.capital.get_forum_msg}"
      end
      
      return resp
    end
    
    class City
      attr_accessor :city_id
      attr_accessor :island_id
      
      attr_accessor :island_name
      attr_accessor :island_res
      
      attr_accessor :population_count
      attr_accessor :population_max
      
      # только в городе или для всего акка?
      attr_accessor :game_actions
      
      attr_accessor :wood
      attr_accessor :wine
      attr_accessor :marble
      attr_accessor :glass
      attr_accessor :sulfur
      
      attr_accessor :transporters_count
      attr_accessor :transporters_max
      
      attr_accessor :accaunt
      
      def initialize(player_accaunt)
        self.accaunt = player_accaunt
      end
      
      def get_forum_msg
        data = "view=islandBoard&id=#{@island_id}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        resp = @accaunt.get2(path + '?' + data)
        doc = Hpricot(resp.body)
         (doc/"div[@class='contentBox01h']/div[@class='content']/").text.strip
    end
    
    def set_wood_workers(worker_count)
      data = "view=resource&type=resource&id=#{@island_id}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        # get actionReq
        resp = @accaunt.get2(path + '?' + data)
        doc = Hpricot(resp.body)
        
        actionReq = (doc/"input[@name='actionRequest']")[0].attributes['value']
        
        data = "view=resource&type=resource&id=#{@island_id}&action=IslandScreen&function=workerPlan" +
      "&cityId=#{@city_id}&actionRequest=#{actionReq}&rw=#{worker_count}"
        
        resp = @accaunt.post(path, data)
        puts "set wood workers: #{worker_count}" 
        true
      end
      
      # лучше в новый класс Island
      def donate_wood(wood_count)
        data = "view=resource&type=resource&id=#{@island_id}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        # get actionReq
        resp = @accaunt.get2(path + '?' + data)
        doc = Hpricot(resp.body)
        
        actionReq = (doc/"input[@name='actionRequest']")[0].attributes['value']
        
        data = "view=resource&type=resource&id=#{@island_id}&action=IslandScreen&function=donate" +
      "&cityId=#{@city_id}&actionRequest=#{actionReq}&donation=#{wood_count}"
        
        resp = @accaunt.post(path, data)
        puts "donate wood #{wood_count}"
        true
      end
      
      def build(build_place, building)
        building_index = get_building_id(building)
        
        data = "view=buildingGround&id=#{@city_id}&position=#{build_place}"
        
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        # get actionReq
        resp = @accaunt.get2(path + '?' + data )
        doc = Hpricot(resp.body)
        
        actionReq = (doc/"a[@class='button build']")[0].attributes['href'].split("&")[2]
        
        data = "action=CityScreen&function=build&#{actionReq}"+
            "&id=#{@city_id}&position=#{build_place}&building=#{building_index}"
        
        resp = @accaunt.get2(path + '?' + data)
        doc = Hpricot(resp.body)
        build_time = (doc/"span[@id='cityCountdown']").text
        
        puts "build: #{building} with time #{build_time}"
        true
      end
      
      def upgrade_building(build_place)      
        data = "view=city&id=#{@city_id}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        # city view - get link to building
        resp = @accaunt.get2(path + '?' + data)
        doc = Hpricot(resp.body)
        position = "position#{build_place}"
        link = (doc/"li[@id='#{position}']/a")[0].attributes['href']
    
      # go to building view
      resp = @accaunt.get2(path + link)
      doc = Hpricot(resp.body)
      # get link to upgrade
      link = (doc/"li[@class='upgrade']/a")[0].attributes['href']
      resp = @accaunt.get2(path + link)
      
      doc = Hpricot(resp.body)
      build_time = (doc/"span[@id='cityCountdown']").text
      
      puts "upgrade building at place: #{build_place} with time #{build_time}"
        true
      end
      
      def get_build_time
        data = "view=city&id=#{@city_id}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        resp = @accaunt.get2(path + '?' + data )
        doc = Hpricot(resp.body)
        
        # 1мин. 20с.
        t = (doc/"span[@id='cityCountdown']").text
        puts "build time: #{t}"
        t
      end
      
      def set_scientists(build_place, count)
        data = "view=academy&id=#{@city_id}&position=#{build_place}"
        @accaunt.headers("http://#{@accaunt.game_server}/index.php?view=resource&type=resource&id=#{@island_id}")
        
        # get actionReq
        resp = @accaunt.get2(path + '?' + data)
        
        doc = Hpricot(resp.body)
        
        actionReq = (doc/"input[@name='actionRequest']")[0].attributes['value']
        
        data = "view=academy&type=resource&id=#{@island_id}&action=IslandScreen&function=workerPlan" +
      "&cityId=#{@city_id}&actionRequest=#{actionReq}&s=#{count}"
        
        resp = @accaunt.post(path, data)
        puts "set scientists: #{count}"
        true  
      end
      
      private
      def path
      '/index.php'
      end
      
      def get_building_id(building)
        result = case building
          when "Ратуша" then 0
          when "Академия" then 4
          when "Склад" then 7
          when "Таверна" then 9
          when "Дворец" then 11
          when "Резиденция губернатора" then 17
          when "Музей" then 10
          when "Торговый порт" then 3
          when "Верфь" then 5
          when "Казарма" then 6
          when "Городская стена" then 8
          when "Посольство" then 12
          when "Рынок" then 13
          when "Мастерская" then 15
          when "Укрытие" then 16
          when "Хижина Лесничего" then 18
          when "Стеклодувная Мастерская" then 20
          when "Башня Алхимика" then 22
          when "Винодельня" then 21
          when "Каменоломня" then 19
          when "Плотницкая мастерская" then 23
          when "Оптика" then 25
          when "Полигон Пиротехника" then 27
          when "Винный погреб" then 26
          when "Бюро Архитектора" then 24
          when "Храм" then 28        
        end
        result    
      end
    end
    
  end
  
end