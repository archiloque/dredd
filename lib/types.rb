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
      errors.add("", "[#{openid_identifier} n'est pas une adresse valide")
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

    String :address, :null => false
    String :server_address, :null => false
    String :password, :null => false
    Boolean :ssl, :null => false
    Integer :port, :null => false, :unsigned => true

    Boolean :enabled, :null => false, :default => true

    Boolean :last_connection_successful
    String :last_connection_error_message
    DateTime :last_connection_date

    DateTime :created_at, :null => false
    DateTime :updated_at
  end
end

class Account < Sequel::Model

  plugin :timestamps

  def validate
    if name.blank?
      errors.add("", "Le nom du compte est vide")
    end
    if address.blank?
      errors.add("", "L'addresse mail est vide")
    end
    if server_address.blank?
      errors.add("", "L'addresse du serveur est vide")
    end
    if password.blank?
      errors.add("", "Le mot de passe est vide")
    end
    if port.blank?
      errors.add("", "Le port est vide")
    else
      begin
        Integer(port)
      rescue ArgumentError
        errors.add("", "La valeur du port est invalide")
      end
    end
  end

  def update_after_connection successfull, error_message = nil
    self.last_connection_date = DateTime.now
    self.last_connection_successful = successfull
    self.last_connection_error_message = error_message
    save
  end

end