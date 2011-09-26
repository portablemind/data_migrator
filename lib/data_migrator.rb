require "benchmark"

class DataMigrationTask < Rails::Railtie
  rake_tasks do
    Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
  end
end

module RussellEdge
  class DataMigrator
    REMOVE_FILES_REGEX = /^\./
    
    class << self
      def next_migration_number
    	  Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
    
      def initialize_data_migrations_table
        puts "** data_migrations table missing creating now...."
        puts ActiveRecord::Migrator.run(:up, File.join(File.dirname(__FILE__),'../db/migrate/'), 20100819181805)
        puts "** done"
      end
      
      def prepare_migrations
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

      def cleanup_migrations
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
    end
    
    def initialize(migrations_path=nil)
      @default_migrations_path = migrations_path || "#{Rails.root}/db/data_migrations"
    end
      
    def migrate(passed_location=nil, passed_version=nil)
      setup
   
      location = passed_location.nil? ? @default_migrations_path  : passed_location
      @@current_version = get_current_version

      if passed_version.nil? || @@current_version.nil?
        run_all_non_migrated(passed_version)
      elsif passed_version < @@current_version
        handle_lower_passed_version(passed_version)
      elsif passed_version > @@current_version
        handle_higher_passed_version(passed_version)
      end
    end
  
    def pending_migrations
      versions = []
      files = get_all_files
      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        versions << filename unless version_has_been_migrated?(version)
      end

      versions
    end

    def get_current_version
      result = ActiveRecord::Base.connection.select_all("select max(version) as current_version from data_migrations")

      current_version = result[0]['current_version'] unless result == -1

      current_version = current_version.to_i unless current_version.nil?

      current_version
    end
  
    def run_up(passed_version)
      setup
    
      raise "VERSION is required" unless passed_version
    
      files = get_all_files
      found = false
    
      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        if passed_version == version
          found = true
          (version_has_been_migrated?(version)) ? (puts "** Version #{passed_version} has already been migrated") : handle_action(file, klass_name, version, :up)
        end
      end
    
      puts "** Version #{passed_version} not found" unless found
    
    end
  
    def run_down(passed_version)
      setup
    
      raise "VERSION is required" unless passed_version
    
      files = get_all_files
      found = false 

      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        if passed_version == version
          found = true
          (version_has_been_migrated?(version)) ? handle_action(file, klass_name, version, :down) : (puts "** Version #{passed_version} has not been migrated")
        end
      end
    
      puts "** Version #{passed_version} not found" unless found
    
    end
	
    private
  
    def setup
      RussellEdge::DataMigrator.initialize_data_migrations_table unless data_migrations_table_exists?
      
      unless File.directory?  @default_migrations_path
        FileUtils.mkdir_p( @default_migrations_path)
        #create ignore folder
        FileUtils.mkdir_p(File.join(@default_migrations_path,'ignore/'))
      end
    end
  
    def handle_higher_passed_version(passed_version)
      files = get_all_files

      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        if version <= passed_version
          unless version_has_been_migrated?(version)
            handle_action(file, klass_name, version, :up)
          end
        end
      end

    end

    def run_all_non_migrated(passed_version)
      files = get_all_files

      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        if passed_version.nil? or version <= passed_version
          if !version_has_been_migrated?(version) 
            handle_action(file, klass_name, version, :up)
          end
        end
      end
    end

    def handle_lower_passed_version(passed_version)
      files = get_all_files

      files.each do |file|
        filename, version, klass_name = seperate_file_parts(file)
        if version > passed_version
          handle_action(file, klass_name, version, :down) if version_has_been_migrated?(version)
        end
      end

    end

    def handle_action(file, klass_name, version, action)
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
        RussellEdge::DataMigrator.cleanup_migrations
        raise ex
      end
      time_str = "(%.4fs)" % time.real
      puts "================Finished #{klass.to_s} in #{time_str}=="
      
      (action == :up) ? insert_migration_version(version) : remove_migration_version(version)
    end
  
    def insert_migration_version(version)
      ActiveRecord::Base.connection.execute("insert into data_migrations (version) values ('#{version}')")
    end

    def remove_migration_version(version)
      ActiveRecord::Base.connection.execute("delete from data_migrations where version = '#{version}'")
    end

    def version_has_been_migrated?(version)
      result = true

      db_result = ActiveRecord::Base.connection.select_all("select count(*) as num_rows from data_migrations where version = '#{version}'")

      num_rows = db_result[0]['num_rows'] unless db_result == -1
    
      result = false if (num_rows.nil? || num_rows.to_i == 0)
      result
    end

    def data_migrations_table_exists?
      table_names =  ActiveRecord::Base.connection.tables
      table_names.include?('data_migrations')
    end

    def seperate_file_parts(file)
      paths = file.split('/')
      filename = paths[paths.length - 1]
      version = filename.split('_')[0]
      klass_name = filename.gsub(/#{version}/, "").gsub(/.rb/, "")[1..filename.length]

      return filename, version.to_i, klass_name
    end

    def get_all_files
      files = []
    
      if File.directory? @default_migrations_path
    
        files_or_directories = Dir.entries(@default_migrations_path).map{|directory| directory}

        files_or_directories.delete_if{|name| name =~ REMOVE_FILES_REGEX} #remove any file leading with . or ..
        files_or_directories.delete_if{|name| name == 'ignore'} #ignore the ignore folder

      
        files_or_directories.each do |file_or_directory|
          file_or_directory = @default_migrations_path + "/" + file_or_directory
          files = get_files_in_directory(file_or_directory, files)
        end

        files.sort! {|x,y| File.basename(x) <=> File.basename(y)}
      end

      files
    end

    def get_files_in_directory(file_or_directory, files)
      unless file_or_directory =~ /\w\.rb/
        files_or_directories = Dir.entries(file_or_directory).map{|directory| directory}

        files_or_directories.delete_if{|name| name =~ REMOVE_FILES_REGEX} #remove any file leading with . or ..
        files_or_directories.delete_if{|name| name == 'ignore'} #ignore the ignore folder

        files_or_directories.each do |_file_or_directory|
          _file_or_directory = file_or_directory + "/" + _file_or_directory
          files = get_files_in_directory(_file_or_directory, files)
        end
      else
        files << file_or_directory
      end

      files
    end
  end
end