namespace :db do
  desc 'migrates data into database'
  task :migrate_data => :environment do
      
    passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    DataMigrator.prepare_migrations
    DataMigrator.migrate(nil, passed_version)
	  DataMigrator.cleanup_migrations
      
  end#end task
    
  namespace :migrate_data do
	task :list_pending => :environment do
      DataMigrator.prepare_migrations
      pending_migrations = DataMigrator.pending_migrations
      puts "================Pending Data Migrations=========="
      puts pending_migrations
      puts "================================================="
      DataMigrator.cleanup_migrations
    end

    task :version => :environment do
      version = DataMigrator.get_current_version

      unless version.nil?
        puts "** Current version #{version}"
      else
        puts "** No migrations ran"
      end
    end
      
    task :up => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
        
      DataMigrator.prepare_migrations
      DataMigrator.run_up(passed_version)
      DataMigrator.cleanup_migrations
        
    end#end task
      
    task :down => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
		
      DataMigrator.prepare_migrations
      DataMigrator.run_down(passed_version)
      DataMigrator.cleanup_migrations
        
    end#end task
  end#end namespace
end


