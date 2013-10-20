namespace :db do
  desc 'migrates data into database'
  task :migrate_data => :environment do
    passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil

    RussellEdge::DataMigrator.new.migrate(nil, passed_version)

    Rake::Task["db:schema:dump"].reenable
    Rake::Task["db:schema:dump"].invoke
  end#end migrate_data task
    
  namespace :migrate_data do
	task :list_pending => :environment do
      pending_migrations = RussellEdge::DataMigrator.new.pending_migrations
      puts "================Pending Data Migrations=========="
      puts pending_migrations
      puts "================================================="
    end#end list_pending task

    task :version => :environment do
      version = RussellEdge::DataMigrator.new.get_current_version
      puts (version.nil?) ? "** No migrations ran" : "** Current version #{version}"
    end#end version task
      
    task :up => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version

      RussellEdge::DataMigrator.new.run_up(passed_version)

      Rake::Task["db:schema:dump"].reenable
      Rake::Task["db:schema:dump"].invoke
    end#end up task
      
    task :down => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version

      RussellEdge::DataMigrator.new.run_down(passed_version)

      Rake::Task["db:schema:dump"].reenable
      Rake::Task["db:schema:dump"].invoke
    end#end down task
  end#end namespace
end

namespace :railties do
  namespace :install do
    # desc "Copies missing data_migrations from Railties (e.g. plugins, engines). You can specify Railties to use with FROM=railtie1,railtie2"
    task :data_migrations => :environment do
      to_load = ENV['FROM'].blank? ? :all : ENV['FROM'].split(",").map {|n| n.strip }
      #added to allow developer to perserve timestamps
      preserve_timestamp = ENV['PRESERVE_TIMESTAMPS'].blank? ? false : (ENV['PRESERVE_TIMESTAMPS'].to_s.downcase == "true")
      #refresh will replace migrations from engines
      refresh = ENV['REFRESH'].blank? ? false : (ENV['REFRESH'].to_s.downcase == "true")
      railties = ActiveSupport::OrderedHash.new
      Rails.application.railties.all do |railtie|
        next unless to_load == :all || to_load.include?(railtie.railtie_name)

        if railtie.respond_to?(:paths) && (path = railtie.paths['db/data_migrations'].first)
          railties[railtie.railtie_name] = path
        end
      end

      on_skip = Proc.new do |name, migration|
        puts "NOTE: Data Migration #{migration[:name]} from #{name} has been skipped. Migration with the same name already exists."
      end

      on_copy = Proc.new do |name, migration, old_path|
        puts "Copied data_migration #{migration[:name]} from #{name}"
      end

      RussellEdge::DataMigrator.copy(RussellEdge::DataMigrator.migrations_path, railties, 
                                     :on_skip => on_skip, 
                                     :on_copy => on_copy, 
                                     :preserve_timestamp => preserve_timestamp,
                                     :refresh => refresh)
    end #data_migrations
    
  end #install
end #railties


