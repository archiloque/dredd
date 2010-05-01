require 'rubygems'
require 'bundler'
Bundler.setup
require 'sinatra/base'
require 'sass'
require 'erb'
require 'dm-core'
require 'dm-validations'
require 'dm-types'
require 'dm-timestamps'
require 'dm-aggregates'
require 'andand'

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/dredd.sqlite3")

require 'lib/types'

class Dredd < Sinatra::Base

  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'

  # open id
  use Rack::Session::Pool
  require 'rack/openid'
  use Rack::OpenID

  def check_logged
    true
    #if session[:user]
    #  true
    #else
    #  redirect '/login'
    #  false
    #end
  end

  get '/' do
    erb :index
  end

  get '/login' do
    @title = 'Login'
    erb :login
  end

  post '/login' do
    if resp = request.env['rack.openid.response']
      if resp.status == :success
        session[:user] = resp
        redirect '/'
      else
        halt 404, "Error: #{resp.status}"
      end
    else
      openid = params[:openid_identifier]
      if User.count(:openid_identifier => openid) == 0
        halt 403, 'Identifiant openid non connu'
      else
        headers 'WWW-Authenticate' => Rack::OpenID.build_header(:identifier => params[:openid_identifier])
        halt 401, 'got openid?'
      end
    end
  end

  get '/logout' do
    session[:user] = nil
    redirect '/'
  end

  get '/admin' do
    if check_logged
      @title = 'Administration'
      @email_from = Meta.first(:name => :email_from).andand.value
      @email_to = Meta.first(:name => :email_to).andand.value
      @default_header = Meta.first(:name => :default_header).andand.value
      @default_body = Meta.first(:name => :default_body).andand.value
      erb :admin
    end
  end

  post '/admin' do
    if check_logged
      [:email_from, :email_to, :default_header, :default_body].each do |key|
        if Meta.count(:name => key) == 0
          Meta.new(:name => key, :value => params[key]).save
        else
          Meta.first(:name => key).update(:value => params[key])
        end
      end
      redirect '/admin'
    end
  end

  get '/stylesheet.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :stylesheet
  end

end