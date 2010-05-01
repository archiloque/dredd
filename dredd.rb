require 'rubygems'
require 'sinatra/base'

class Dredd < Sinatra::Base

  get '/' do
    'Hello world!'
  end

end