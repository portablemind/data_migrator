namespace :db do
  desc 'migrates data into database'
  task :migrate_data => :environment do
    passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    data_migrator = RussellEdge::DataMigrator.new
    data_migrator.prepare_migrations
    data_migrator.migrate(nil, passed_version)
	  data_migrator.cleanup_migrations
      
  end#end migrate_data task
    
  namespace :migrate_data do
	task :list_pending => :environment do
      data_migrator = RussellEdge::DataMigrator.new
      data_migrator.prepare_migrations
      pending_migrations = data_migrator.pending_migrations
      puts "================Pending Data Migrations=========="
      puts pending_migrations
      puts "================================================="
      data_migrator.cleanup_migrations
    end#end list_pending task

    task :version => :environment do
      data_migrator = RussellEdge::DataMigrator.new
      version = data_migrator.get_current_version

      puts (version.nil?) ? "** No migrations ran" : "** Current version #{version}"
    end#end version task
      
    task :up => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
      
      data_migrator = RussellEdge::DataMigrator.new  
      data_migrator.prepare_migrations
      data_migrator.run_up(passed_version)
      data_migrator.cleanup_migrations
        
    end#end up task
      
    task :down => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
		  
		  data_migrator = RussellEdge::DataMigrator.new 
      data_migrator.prepare_migrations
      data_migrator.run_down(passed_version)
      data_migrator.cleanup_migrations
        
    end#end down task
  end#end namespace
end


