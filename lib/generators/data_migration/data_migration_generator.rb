class DataMigrationGenerator < Rails::Generator::NamedBase
  def initialize(runtime_args, runtime_options = {})
    @@location = runtime_args[1]
    super
  end

  def manifest
    record do |m|

      #Migration
      m.migration_template "migrate/migration_template.rb", @@location || 'db/data_migrations', {:migration_file_name => "#{file_name}"}
      
    end
  end
end
