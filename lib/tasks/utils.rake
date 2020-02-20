desc 'Import data from json file'
task :optim_reload_json, [:file_name] => :environment do |_task, args|
  start_time = Time.now
  %w[City Bus Service Trip].each { |model| model.classify.constantize.delete_all }
  Buses::Service.delete_all
  puts "Cleared tables #{Time.now - start_time} sec"
  increment = 0
  model_servicies_size = Service::SERVICES.size

  cities = []
  db_cities = []
  servicies = []
  db_servicies = []

  File.open(args.file_name) do |ff|
    nesting = 0
    str = +""

    while !ff.eof?
      ch = ff.read(1) # читаем по одному символу
      case
      when ch == '{' # начинается объект, повышается вложенность
        nesting += 1
        str << ch
      when ch == '}' # заканчивается объект, понижается вложенность
        nesting -= 1
        str << ch
        if nesting == 0 # если закончился объкет уровня trip, парсим и импортируем его
          trip = Oj.load(str)
          # my_import(trip)
          # puts trip
          # ImportService.new(trip).call

          # import cities
          from = trip['from']

          if cities.index(from).nil?
            cities << from
            db_cities << City.new(name: from)
          end

          to = trip['to']

          if cities.index(to).nil?
            cities << to
            db_cities << City.new(name: to)
          end
          # end import cities

          # import servicies
          if servicies.size < model_servicies_size
            trip['bus']['services'].each do |service|
              next if servicies.index(to).present?

              servicies << service
              db_servicies << Service.new(name: service)
            end
          end
          # end import servicies

          increment += 1
          str = +""
        end
      when nesting >= 1
        str << ch
      end
    end
  end
  City.import db_cities
  Service.import db_servicies

  puts "#{increment} records"
  puts "#{Time.now - start_time} sec"
end


# Наивная загрузка данных из json-файла в БД
# rake reload_json[fixtures/small.json]
task :reload_json, [:file_name] => :environment do |_task, args|
  start_time = Time.now
  increment = 0
  json = JSON.parse(File.read(args.file_name))

  ActiveRecord::Base.transaction do
    City.delete_all
    Bus.delete_all
    Service.delete_all
    Trip.delete_all
    ActiveRecord::Base.connection.execute('delete from buses_services;')

    json.each do |trip|
      increment += 1
      from = City.find_or_create_by(name: trip['from'])
      to = City.find_or_create_by(name: trip['to'])
      services = []
      trip['bus']['services'].each do |service|
        s = Service.find_or_create_by(name: service)
        services << s
      end
      bus = Bus.find_or_create_by(number: trip['bus']['number'])
      bus.update(model: trip['bus']['model'], services: services)

      Trip.create!(
        from: from,
        to: to,
        bus: bus,
        start_time: trip['start_time'],
        duration_minutes: trip['duration_minutes'],
        price_cents: trip['price_cents'],
      )
    end
  end
  puts "#{increment} records"
  puts "#{Time.now - start_time} sec"
end
