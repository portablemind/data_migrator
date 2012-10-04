Rails::Engine::Configuration.class_eval do
  def paths
    @paths ||= begin
      paths = Rails::Paths::Root.new(@root)
      paths.add "app",                 :eager_load => true, :glob => "*"
      paths.add "app/assets",          :glob => "*"
      paths.add "app/controllers",     :eager_load => true
      paths.add "app/helpers",         :eager_load => true
      paths.add "app/models",          :eager_load => true
      paths.add "app/mailers",         :eager_load => true
      paths.add "app/views"
      paths.add "lib",                 :load_path => true
      paths.add "lib/assets",          :glob => "*"
      paths.add "lib/tasks",           :glob => "**/*.rake"
      paths.add "config"
      paths.add "config/environments", :glob => "#{Rails.env}.rb"
      paths.add "config/initializers", :glob => "**/*.rb"
      paths.add "config/locales",      :glob => "*.{rb,yml}"
      paths.add "config/routes",       :with => "config/routes.rb"
      paths.add "db"
      paths.add "db/migrate"
      paths.add "db/data_migrations"
      paths.add "db/seeds",            :with => "db/seeds.rb"
      paths.add "vendor",              :load_path => true
      paths.add "vendor/assets",       :glob => "*"
      paths.add "vendor/plugins"
      paths
    end
  end
end