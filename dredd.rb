require 'rubygems'
require 'bundler'
require 'logger'
require 'andand'

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
  require 'lib/mail'
  helpers Sinatra::DreddMailHelper

  use Rack::Flash

  before do
    # @user_logged = session[:user]
    @user_logged = true
  end

  get '/' do
    erb :'index.html'
  end

  get '/accounts/?' do
    @title = 'Comptes'
    @enabled_accounts = Account.where(:enabled => true).order(:name)
    @disabled_accounts = Account.where(:enabled => false).order(:name)
    erb :'accounts/list.html'
  end

  get '/accounts/:name' do
    @account = Account.where(:name => params[:name]).first
    if @account
      @title = @account.name
      erb :'accounts/show.html'
    else
      flash[:error] = 'Ce compte n\'existe pas'
      redirect '/accounts'
    end
  end

  get '/edit_account/:name' do
    if check_logged
      @account = Account.where(:name => params[:name]).first
      if @account
        @title = "Editer #{@account.name}"
        erb :'accounts/edit.html'
      else
        flash[:error] = 'Ce compte n\'existe pas'
        redirect '/accounts'
      end
    end
  end

  post '/edit_account/:name' do
    if check_logged
      @account = Account.where(:name => params[:name]).first
      unless @account
        halt 404, 'Ce compte n\'existe pas'
      end
      @account.name = params[:account][:name].downcase
      @account.address = params[:account][:address]
      @account.server_address = params[:account][:server_address]
      @account.password = params[:account][:password]
      @account.ssl = params[:account][:ssl] || false
      @account.port = params[:account][:port]
      @account.enabled = params[:account][:enabled]
      begin
        @account.save
        flash[:notice] = 'Compte modifié'
        redirect "/accounts/#{@account.name}"
      rescue Sequel::ValidationFailed => e
        flash[:error] = e.errors
        erb :'accounts/edit.html'
      end
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
      if Account.filter(:name => name).count != 0
        flash[:error] = "Il y a déjà un compte avec ce nom"
        erb :'accounts/edit.html'
      else
        @account = Account.new(:name => name,
                               :address => params[:account][:address],
                               :server_address => params[:account][:server_address],
                               :password => params[:account][:password],
                               :ssl => params[:account][:ssl] || false,
                               :port => params[:account][:port],
                               :enabled => params[:account][:enabled])
        begin
          @account.save
          flash[:notice] = 'Compte créé'
          redirect "/accounts/#{@account.name}"
        rescue Sequel::ValidationFailed => e
          flash[:error] = e.errors
          erb :'accounts/edit.html'
        end
      end
    end
  end

  get '/test_account/:name' do
    if check_logged_ajax
      account = Account.where(:name => params[:name]).first
      unless account
        halt 404, 'Ce compte n\'existe pas'
      end
      begin
        test_account account
        account.update_after_connection true
        body '<div class="messageOK">OK !</div>'
      rescue Exception => e
        account.update_after_connection false, error_2_text(e)
        body "<div class=\"messageKO\">#{error_2_html(e)}</div>"
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
        flash[:notice] = 'Connecté'
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
    flash[:notice] = 'Déconnecté'
    redirect '/'
  end

  get '/admin' do
    if check_logged
      @title = 'Administration'
      erb :'admin/index.html'
    end
  end

  get '/config' do
    if check_logged
      @title = 'Configuration'
      @email_from = Meta.where(:name => 'email_from').first.andand.value
      @email_to = Meta.where(:name => 'email_to').first.andand.value
      @default_header = Meta.where(:name => 'default_header').first.andand.value
      @default_body = Meta.where(:name => 'default_body').first.andand.value
      erb :'admin/config.html'
    end
  end

  post '/config' do
    if check_logged
      ['email_from', 'email_to', 'default_header', 'default_body'].each do |key|
        if Meta.filter(:name => key).count == 0
          meta = Meta.new
          meta.name = key
          meta.value = params[key]
          meta.save
        else
          meta = Meta.where(:name => key).first
          meta.value =  params[key]
          meta.save
        end
      end
      flash[:notice] = 'Données mises à jour'
      redirect '/config'
    end
  end


  get '/stylesheet.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass :stylesheet
  end

  private

  def check_logged
    true
    #if @user_logged
    #  true
    #else
    #  redirect '/login'
    #  false
    #end
  end

  def check_logged_ajax
    true
    #if @user_logged
    #  true
    #else
    #  'Réservé aux administrateurs'
    #  false
    #end
  end

end