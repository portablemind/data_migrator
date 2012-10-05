Rails::Engine.class_eval do
  rake_tasks do
    next if self.is_a?(Rails::Application)
    next unless has_data_migrations?

    namespace railtie_name do
      namespace :install do
        desc "Copy data_migrations from #{railtie_name} to application"
        task :data_migrations do
          ENV["FROM"] = railtie_name
          Rake::Task["railties:install:data_migrations"].invoke
        end
      end
    end
  end

  protected

  def has_data_migrations?
    paths["db/data_migrations"].existent.any?
  end

end