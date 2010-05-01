class User
  include DataMapper::Resource
  property :openid_identifier, URI, :required => true, :index => true, :key => true
end

User.auto_upgrade!
