class DataMigrationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('../templates', __FILE__)
  
  def generate_layout  
    template "migration_template.rb", "db/data_migrations/#{DataMigrator.next_migration_number}_#{file_name}.rb" 
  end  
end