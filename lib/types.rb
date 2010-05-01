class User
  include DataMapper::Resource
  property :openid_identifier, URI, :required => true, :index => true, :key => true
end

User.auto_upgrade!

class Meta
  include DataMapper::Resource
  property :name, String, :required => true, :index => true, :key => true
  property :value, Text, :required => false
end

Meta.auto_upgrade!