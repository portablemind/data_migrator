require "benchmark"

class DataMigrationTask < Rails::Railtie
  rake_tasks do
    Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
  end
end

class DataMigrator
  DEFAULT_MIGRATIONS_PATH = "#{Rails.root}/db/data_migrations"
  REMOVE_FILES_REGEX = /^\./
  
  def self.migrate(passed_location=nil, passed_version=nil)
    self.setup
   
    location = passed_location.nil? ? DEFAULT_MIGRATIONS_PATH  : passed_location
    @@current_version = get_current_version

    if passed_version.nil? || @@current_version.nil?
      self.run_all_non_migrated(passed_version)
    elsif passed_version < @@current_version
      self.handle_lower_passed_version(passed_version)
    elsif passed_version > @@current_version
      self.handle_higher_passed_version(passed_version)
    end
  end
  
  def self.pending_migrations
    versions = []
    files = self.get_all_files
    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      unless version_has_been_migrated?(version)
        versions << filename
      end
    end

    versions
  end

  def self.get_current_version
    result = ActiveRecord::Base.connection.select_all("select max(version) as current_version from data_migrations")

    current_version = result[0]['current_version'] unless result == -1

    current_version = current_version.to_i unless current_version.nil?

    current_version
  end
  
  def self.next_migration_number
	Time.now.utc.strftime("%Y%m%d%H%M%S")
  end
  
  def self.run_up(passed_version)
    self.setup
    
    raise "VERSION is required" unless passed_version
    
    files = self.get_all_files
    found = false
    
    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      if passed_version == version
        found = true
        unless self.version_has_been_migrated?(version)
          self.handle_action(file, klass_name, version, :up)
        else
          puts "** Version #{passed_version} has already been migrated"
        end
      end
    end
    
    unless found
      puts "** Version #{passed_version} not found"
    end
    
  end
  
  def self.run_down(passed_version)
    self.setup
    
    raise "VERSION is required" unless passed_version
    
    files = self.get_all_files
    found = false 

    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      if passed_version == version
        found = true
        if self.version_has_been_migrated?(version)
          self.handle_action(file, klass_name, version, :down)
        else
          puts "** Version #{passed_version} has not been migrated"
        end
      end
    end
    
    unless found
      puts "** Version #{passed_version} not found"
    end
    
  end
  
  def self.prepare_migrations
    target = "#{Rails.root}/db/data_migrations/"

    # first copy all app data_migrations away
    files = Dir["#{target}*.rb"]

    unless files.empty?
      FileUtils.mkdir_p "#{target}/ignore/app/"
      FileUtils.cp files, "#{target}/ignore/app/"
      puts "copied #{files.size} data_migrations to db/data_migrations/ignore/app"
    end

    dirs = Rails::Application::Railties.engines.map{|p| p.config.root.to_s}
    files = Dir["{#{dirs.join(',')}}/db/data_migrations/*.rb"]

    unless files.empty?
      FileUtils.mkdir_p target
      FileUtils.cp files, target
      puts "copied #{files.size} migrations to db/data_migrations"
    end
  end
  
  def self.cleanup_migrations
    target = "#{Rails.root}/db/data_migrations/"
      
	  files = Dir["#{target}*.rb"]
    unless files.empty?
      FileUtils.rm files
      puts "removed #{files.size} data_migrations from db/data_migrations"
    end
    files = Dir["#{target}/ignore/app/*.rb"]
    unless files.empty?
      FileUtils.cp files, target
      puts "copied #{files.size} data_migrations back to db/data_migrations"
    end
    FileUtils.rm_rf "#{target}/ignore/app"
  end
	
  private
  
  def self.setup
    unless self.data_migrations_table_exists?
      self.create_data_migrations_table
    end
    
    unless File.directory? DEFAULT_MIGRATIONS_PATH
      FileUtils.mkdir_p(DEFAULT_MIGRATIONS_PATH)
      #create ignore folder
      FileUtils.mkdir_p(DEFAULT_MIGRATIONS_PATH + '/ignore/')
    end
  end
  
  def self.handle_higher_passed_version(passed_version)
    files = self.get_all_files

    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      if version <= passed_version
        unless self.version_has_been_migrated?(version)
          self.handle_action(file, klass_name, version, :up)
        end
      end
    end

  end

  def self.run_all_non_migrated(passed_version)
    files = self.get_all_files

    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      if passed_version.nil? or version <= passed_version
        if !self.version_has_been_migrated?(version) 
          self.handle_action(file, klass_name, version, :up)
        end
      end
    end
  end

  def self.handle_lower_passed_version(passed_version)
    files = self.get_all_files

    files.each do |file|
      filename, version, klass_name = self.seperate_file_parts(file)
      if version > passed_version
        if self.version_has_been_migrated?(version)
          self.handle_action(file, klass_name, version, :down)
        end
      end
    end

  end

  def self.handle_action(file, klass_name, version, action)
    require file
    klass = klass_name.camelize.constantize
    puts "=================Migrating #{klass.to_s} #{action.to_s.upcase}============"
    begin
      time = Benchmark.measure do
        ActiveRecord::Base.transaction do
          klass.send(action.to_s)
        end
      end
    rescue Exception=>ex
      self.cleanup_migrations
      raise ex
    end
    time_str = "(%.4fs)" % time.real
    puts "================Finished #{klass.to_s} in #{time_str}=="
    self.insert_migration_version(version)
  end
  
  def self.insert_migration_version(version)
    ActiveRecord::Base.connection.execute("insert into data_migrations (version) values ('#{version}')")
  end

  def self.remove_migration_version(version)
    ActiveRecord::Base.connection.execute("delete from data_migrations where version = '#{version}'")
  end

  def self.version_has_been_migrated?(version)
    result = true

    db_result = ActiveRecord::Base.connection.select_all("select count(*) as num_rows from data_migrations where version = '#{version}'")

    num_rows = db_result[0]['num_rows'] unless db_result == -1

    if num_rows.nil? || num_rows.to_i == 0
      result = false
    end

    result
  end

  def self.data_migrations_table_exists?
    table_names =  ActiveRecord::Base.connection.tables
    table_names.include?('data_migrations')
  end

  def self.create_data_migrations_table
    puts "** data_migrations table missing creating now...."
    puts ActiveRecord::Migrator.run(:up, File.join(File.dirname(__FILE__),'../db/migrate/'), 20100819181805)
    puts "** done"
  end

  def self.seperate_file_parts(file)
    paths = file.split('/')
    filename = paths[paths.length - 1]
    version = filename.split('_')[0]
    klass_name = filename.gsub(/#{version}/, "").gsub(/.rb/, "")[1..filename.length]

    return filename, version.to_i, klass_name
  end

  def self.get_all_files
    files = []
    
    if File.directory? DEFAULT_MIGRATIONS_PATH
    
      files_or_directories = Dir.entries(DEFAULT_MIGRATIONS_PATH).map{|directory| directory}

      files_or_directories.delete_if{|name| name =~ REMOVE_FILES_REGEX} #remove any file leading with . or ..
      files_or_directories.delete_if{|name| name == 'ignore'} #ignore the ignore folder

      
      files_or_directories.each do |file_or_directory|
        file_or_directory = DEFAULT_MIGRATIONS_PATH + "/" + file_or_directory
        files = self.get_files_in_directory(file_or_directory, files)
      end

      files.sort! {|x,y| self.get_file_name(x) <=> self.get_file_name(y)}
    end

    files
  end

  def self.get_files_in_directory(file_or_directory, files)
    unless file_or_directory =~ /\w\.rb/
      files_or_directories = Dir.entries(file_or_directory).map{|directory| directory}

      files_or_directories.delete_if{|name| name =~ REMOVE_FILES_REGEX} #remove any file leading with . or ..
      files_or_directories.delete_if{|name| name == 'ignore'} #ignore the ignore folder

      files_or_directories.each do |_file_or_directory|
        _file_or_directory = file_or_directory + "/" + _file_or_directory
        files = self.get_files_in_directory(_file_or_directory, files)
      end
    else
      files << file_or_directory
    end

    files
  end

  def self.get_file_name(dir)
    file_name = dir

    paths = dir.split('/')
    file_name = paths[paths.length - 1]

    file_name
  end
end