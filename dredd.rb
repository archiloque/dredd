require 'rubygems'
require 'bundler'
require 'logger'

Bundler.setup

require 'sinatra/base'
require 'rack-flash'

ENV['DATABASE_URL'] = "sqlite://#{Dir.pwd}/dredd.sqlite3"
require 'sinatra'
require 'sinatra/sequel'

require 'erb'

class Dredd < Sinatra::Base

  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'

  database.loggers << Logger.new(STDOUT)

  # open id
  use Rack::Session::Pool
  require 'rack/openid'
  use Rack::OpenID

  require 'lib/types'
  require 'lib/helpers'
  helpers Sinatra::DreddHelper

  use Rack::Flash

  before do
    # @user_logged = session[:user]
    @user_logged = true
  end

  def check_logged
    true
    #if @user_logged
    #  true
    #else
    #  redirect '/login'
    #  false
    #end
  end

  get '/' do
    erb :'index.html'
  end

  get '/accounts' do
    @title = 'Comptes'
    @enabled_accounts = Account.where(:enabled => true).order(:name)
    @disabled_accounts = Account.where(:enabled => false).order(:name)
    erb :'accounts/list.html'
  end

  get '/accounts/:id' do
    @account = Account.where(:id => params[:id]).first
    @title = @account.name
    erb :'accounts/show.html'
  end

  get '/edit_account/:id' do
    if check_logged
      @account = Account.where(:id => params[:id]).first
      @title = "Editer #{@account.name}"
      erb :'accounts/edit.html'
    end
  end

  get '/new_account' do
    if check_logged
      @title = 'Nouveau Compte'
      @account = Account.new
      @account.enabled = true
      erb :'accounts/edit.html'
    end
  end

  post '/new_account' do
    if check_logged
      name = params[:account][:name].downcase
      @account = Account.new(:name => name, :address => params[:account][:address], :enabled => params[:account][:enabled])
      begin
        @account.save
        redirect "/accounts/#{@account.id}"
      rescue Sequel::ValidationFailed => e
        flash[:error] = e.errors
        erb :'accounts/edit.html'
      end
    end
  end

  get '/login' do
    @title = 'Login'
    erb :'login.html'
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
      if User.where(:openid_identifier => openid).count == 0
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
      erb :'admin/admin.html'
    end
  end

  post '/admin' do
    if check_logged
      [:email_from, :email_to, :default_header, :default_body].each do |key|
        if Meta.where(:name => key).count == 0
          Meta.create(:name => key, :value => params[key])
        else
          Meta.where(:name => key).update(:value => params[key])
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