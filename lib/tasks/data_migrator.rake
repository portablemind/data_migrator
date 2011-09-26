namespace :db do
  desc 'migrates data into database'
  task :migrate_data => :environment do
    passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    RussellEdge::DataMigrator.prepare_migrations
    RussellEdge::DataMigrator.new.migrate(nil, passed_version)
	  RussellEdge::DataMigrator.cleanup_migrations
      
  end#end migrate_data task
    
  namespace :migrate_data do
	task :list_pending => :environment do
      RussellEdge::DataMigrator.prepare_migrations
      pending_migrations = RussellEdge::DataMigrator.new.pending_migrations
      puts "================Pending Data Migrations=========="
      puts pending_migrations
      puts "================================================="
      RussellEdge::DataMigrator.cleanup_migrations
    end#end list_pending task

    task :version => :environment do
      version = RussellEdge::DataMigrator.new.get_current_version
      puts (version.nil?) ? "** No migrations ran" : "** Current version #{version}"
    end#end version task
      
    task :up => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
       
      RussellEdge::DataMigrator.prepare_migrations
      RussellEdge::DataMigrator.new.run_up(passed_version)
      RussellEdge::DataMigrator.cleanup_migrations
        
    end#end up task
      
    task :down => :environment do
      passed_version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless passed_version
		  
      RussellEdge::DataMigrator.prepare_migrations
      RussellEdge::DataMigrator.new.run_down(passed_version)
      RussellEdge::DataMigrator.cleanup_migrations
        
    end#end down task
  end#end namespace
end


