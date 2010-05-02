require 'email_veracity'

migration "create table users" do
  database.create_table :users do
    primary_key :openid_identifier, :type => String, :null => false, :auto_increment => false
  end
end

class User < Sequel::Model
  def validate
    begin
      URI.parse openid_identifier
    rescue URI::InvalidURIError
      errors.add(:openid_identifier, "n'est pas une adresse valide")
    end
  end
end

migration "create table meta" do
  database.create_table :metas do
    primary_key :name, :type => String, :null => false, :auto_increment => false
    text :value, :null => true
  end
end

class Meta < Sequel::Model
end


migration "create table accounts" do
  database.create_table :accounts do
    primary_key :id, :type=>Integer, :null => false
    String :name, :null => false, :index => true, :unique => true
    String :address, :null => false, :format => :email_address, :unique => true
    Boolean :enabled, :null => false, :default => true
    DateTime :created_at, :null => false
    DateTime :updated_at
  end
end

class Account < Sequel::Model

  plugin :timestamps

  def validate
    if address && ("" != address)
      unless EmailVeracity::Address.new(address).valid?
        errors.add(:address, "[#{address}] n'est pas une adresse email valide")
      end
    end
  end

end