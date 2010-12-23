class CreateDataMigrationsTable < ActiveRecord::Migration
  def self.up
    unless table_exists?(:data_migrations)
     create_table :data_migrations, {:id => false} do |t|
        t.column :version,  :string
      end
    end
  end

  def self.down
    if table_exists?(:data_migrations)
     drop_table :data_migrations
    end
  end
end
