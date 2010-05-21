require 'rubygems'
require 'bundler'
require 'logger'
require 'andand'
require 'tzinfo'

Bundler.setup

require 'sinatra/base'
require 'rack-flash'

ENV['DATABASE_URL'] ||= "sqlite://#{Dir.pwd}/dredd.sqlite3"

require 'sinatra'
require 'sinatra/sequel'

require 'sequel/extensions/named_timezones'
Sequel.default_timezone = TZInfo::Timezone.get('Europe/Paris')

require 'erb'

module Sequel
  class Database
    def table_exists?(name)
      begin
        from(name).first
        true
      rescue Exception
        false
      end
    end
  end
end

class Dredd < Sinatra::Base

  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'
  set :raise_errors, true
  set :show_exceptions, :true

  root_dir = File.dirname(__FILE__)
  set :app_file, File.join(root_dir, 'dredd.rb')

  configure :development do
    database.loggers << Logger.new(STDOUT)
    ALWAYS_LOGGED = true
  end
  configure :production do
    ALWAYS_LOGGED = false
  end

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
    @user_logged = session[:user]
  end

  get '/' do
    @title = 'Messages'
    @original_messages = OriginalMessage.eager_graph(:slower_received_message => :account).order(:id.qualify(:original_messages).desc).limit(100)
    render_original_messages
  end

  get '/message/:year/:month' do
    @title = "Messages #{params[:month]} / #{params[:year]}"
    date = Date.civil(params[:year].to_i, params[:month].to_i, 1)
    @original_messages = OriginalMessage.eager_graph(:slower_received_message => :account).order(:id.qualify(:original_messages).desc).where('sent_at >= ? and sent_at < ?', date, date >> 1)
    render_original_messages
  end

  get '/message/:timestamp' do
    message_datetime = Sequel.database_timezone.local_to_utc(timestamp_2_datetime(params[:timestamp]))
    original_message_hash = OriginalMessage.eager_graph(:slower_received_message => :account).where('original_messages.sent_at = ?', message_datetime).first
    unless original_message_hash
      halt 404, 'Ce message n\'existe pas !'
    end
    @original_message = original_message_hash[:original_messages]
    @title = "Message du #{affiche_date_heure(@original_message.sent_at, "à ")}"
    @received_messages = ReceivedMessage.eager_graph(:account).where(:original_message_id => @original_message.id).order(:delay.qualify(:received_messages).asc)
    @slower_received_message = original_message_hash[:slower_received_message]
    @slower_received_message_account = original_message_hash[:account]

    original_message_calendar
    erb :'message.html'
  end

  get '/account/:name/:year/:month' do
    @account = Account.where(:name => params[:name]).first
    unless @account
      halt 404, 'Ce compte n\'existe pas'
    end
    date = Date.civil(params[:year].to_i, params[:month].to_i, 1)

    @original_messages_hash = {}
    original_messages = OriginalMessage.order(:id.asc).where('sent_at >= ? and sent_at < ?', date, date >> 1)
    if original_messages.empty?
      @received_messages = []
    else
      original_messages.each { |original_message| @original_messages_hash[original_message.id] = original_message }
      min_message_id = @original_messages_hash[@original_messages_hash.keys.min].id
      max_message_id = @original_messages_hash[@original_messages_hash.keys.max].id
      @received_messages = ReceivedMessage.where('original_message_id >= ? and original_message_id <= ? and account_id = ?', min_message_id, max_message_id, @account.id).order(:original_message_id.asc)
    end
    @title = "#{@account.name} #{params[:month]} / #{params[:year]}"
    render_received_messages
  end

  get '/account/:name/:timestamp' do
    @account = Account.where(:name => params[:name]).first
    unless @account
      halt 404, 'Ce compte n\'existe pas'
    end

    message_datetime = Sequel.database_timezone.local_to_utc(timestamp_2_datetime(params[:timestamp]))
    received_message_hash = ReceivedMessage.eager_graph(:original_message).where('original_message.sent_at = ? and account_id = ?', message_datetime, @account.id).first
    unless received_message_hash
      halt 404, 'Ce message n\'existe pas !'
    end
    @received_message = received_message_hash[:received_messages]
    @original_message = received_message_hash[:original_message]
    @title = "Message du #{affiche_date_heure(@original_message.sent_at, "à ")} pour #{@account.name}"
    render_message_calendar
    erb :'account/message.html'
  end

  get '/account/:name' do
    @account = Account.where(:name => params[:name]).first

    unless @account
      halt 404, 'Ce compte n\'existe pas'
    end
    @title = @account.name
    original_messages = OriginalMessage.limit(100)
    if original_messages.empty?
      @received_messages = []
    else
      @received_messages = ReceivedMessage.where('original_message_id >= ?', original_messages.first.id).where(:account_id => @account.id).order(:original_message_id.asc)
    end
    @original_messages_hash = {}
    original_messages.each { |original_message| @original_messages_hash[original_message.id] = original_message }

    render_received_messages
  end

  get '/edit_account/:name' do
    if check_logged
      @account = Account.where(:name => params[:name]).first
      unless @account
        halt 404, 'Ce compte n\'existe pas'
      end
      @title = "Editer #{@account.name}"
      erb :'account/edit.html'
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
        redirect "/account/#{@account.name}"
      rescue Sequel::ValidationFailed => e
        flash[:error] = e.errors
        erb :'account/edit.html'
      end
    end
  end

  get '/new_account' do
    if check_logged
      @title = 'Nouveau Compte'
      @account = Account.new
      @account.enabled = true
      erb :'account/edit.html'
    end
  end

  post '/new_account' do
    if check_logged
      name = params[:account][:name].downcase
      if Account.filter(:name => name).count != 0
        flash[:error] = "Il y a déjà un compte avec ce nom"
        erb :'account/edit.html'
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
          redirect "/account/#{@account.name}"
        rescue Sequel::ValidationFailed => e
          flash[:error] = e.errors
          erb :'account/edit.html'
        end
      end
    end
  end

  get '/test_account/:name' do
    if check_logged_ajax
      account = Account.where(:name => params[:name]).first
      unless account
        halt 404, 'Ce compte n\'existe pas !'
      end
      begin
        found_messages = check_accounts([account])
        body "<div class=\"messageOK\">OK, #{found_messages} message(s) trouvé(s) </div>"
      rescue RuntimeError => e
        body "<div class=\"messageKO\">#{e.message}</div>"
      end
    end
  end

  get '/login' do
    @title = 'Login'
    erb :'login.html'
  end

  get '/ecrire' do
    redirect '/login'
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
      @email_subject = Meta.where(:name => 'email_subject').first.andand.value
      @email_body = Meta.where(:name => 'email_body').first.andand.value
      @backend_password = Meta.where(:name => 'backend_password').first.andand.value
      erb :'admin/config.html'
    end
  end

  post '/config' do
    if check_logged
      ['email_from', 'email_to', 'email_subject', 'email_body', 'backend_password'].each do |key|
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


  post '/send_mail' do
    if check_logged
      message = create_message
      if message
        message.save
        send_message message
        flash[:notice] = 'Mail envoyé'
        redirect '/admin'
      else
        flash[:error] = 'Il manque des valeurs'
        redirect '/config'
      end
    end
  end

  get '/check_all' do
    if check_logged
      begin
        found_messages = check_accounts(Account.where(:enabled => true))
        flash[:notice] = "OK, #{found_messages} message(s) trouvé(s)"
      rescue RuntimeError => e
        flash[:error] = e.message
      end
      redirect '/admin'
    end
  end

  get '/about' do
    @title = 'À propos'
    erb :'about.html'
  end

  get '/backend_send_mail/:backend_password' do
    check_backend

    begin
      message = create_message
      if message
        message.save
        send_message message
        halt 201, 'Mail envoyé'
      else
        halt 403, 'Il manque des valeurs'
      end
    end
  end

  get '/backend_check_mail/:backend_password' do
    check_backend

    begin
      found_messages = check_accounts(Account.where(:enabled => true))
      halt 200, "#{found_messages} nouveau(x) message(s)"
    rescue RuntimeError => e
      halt 500, e.message
    end
  end

  private

  def original_message_calendar
    @calendar_min_date = OriginalMessage.order(:sent_at.asc).first.andand.sent_at
    @calendar_base_url = '/messages/'
  end

  def render_original_messages
    @accounts = Account.order(:name.asc)
    original_message_calendar
    erb :'index.html'
  end

  def render_message_calendar
    first_message = ReceivedMessage.eager_graph(:account, :original_message).order(:original_message_id.asc).where('account_id = ?', @account.id).first
    if first_message
      @calendar_min_date = first_message[:original_message].sent_at
      @calendar_base_url = "/account/#{params[:name]}/"
    end
  end

  def render_received_messages
    render_message_calendar
    erb :'account/show.html'
  end

  def check_logged
    if ALWAYS_LOGGED || @user_logged
      true
    else
      redirect '/login'
      false
    end
  end

  def check_logged_ajax
    if ALWAYS_LOGGED || @user_logged
      true
    else
      body 'Réservé aux administrateurs'
      false
    end
  end

  def check_backend
    unless ALWAYS_LOGGED || (params[:backend_password] == Meta.where(:name => 'backend_password').first.andand.value)
      halt 403, 'Réservé aux administrateurs'
    end
  end

end