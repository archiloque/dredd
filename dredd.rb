# encoding: UTF-8

require 'rubygems'
require 'bundler'
require 'logger'
require 'andand'
require 'tzinfo'
require 'json'

Bundler.setup

require 'sinatra/base'
require 'rack-flash'

ENV['DATABASE_URL'] ||= "sqlite://#{Dir.pwd}/dredd.sqlite3"
ENV['ERROR_OUTPUT_COMMAND'] ||= 'echo '

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
  set :public_folder, File.dirname(__FILE__) + '/public'
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
    @show_days = false
    last_message_id = nil
    database.fetch("SELECT max(id) as m FROM original_messages") do |row|
      last_message_id = row[:m]
    end
    @original_messages = OriginalMessage.order(:id.desc).where('original_messages.id > ?', (last_message_id - 100))
    render_original_messages
  end

  ['/message/:year/:month', '/message/:year/:month/:day'].each do |path|
    get path do
      @title = "Messages #{params[:month]} / #{params[:year]}"
      @show_days = true

      date = Date.civil(params[:year].to_i, params[:month].to_i, 1)
      @original_messages = OriginalMessage.order(:id.desc).where('sent_at >= ? and sent_at < ?', date, date >> 1)
      render_original_messages
    end
  end

  get '/message/:message_id' do
    @original_message = OriginalMessage.where('original_messages.id = ?', params[:message_id]).first
    unless @original_message
      halt 404, 'Ce message n\'existe pas !'
    end
    @title = "Message du #{affiche_date_heure(@original_message.sent_at, "à ")}"
    @received_messages = ReceivedMessage.eager_graph(:account).where(:original_message_id => @original_message.id).order(:delay.qualify(:received_messages).asc)
    if @original_message.slower_received_message_id
      slower_message_hash = ReceivedMessage.eager_graph(:account).where('received_messages.id = ?', @original_message.slower_received_message_id).first
      @slower_received_message = slower_message_hash[:received_messages]
      @slower_received_message_account = slower_message_hash[:account]
    else
      @slower_received_message = nil
      @slower_received_message_account = nil
    end
    original_message_calendar
    erb :'message.html'
  end

  get '/account/:name/message/:message_id' do
    @account = Account.where(:name => params[:name]).first
    unless @account
      halt 404, 'Ce compte n\'existe pas'
    end

    @original_message = OriginalMessage.where('id = ?', params[:message_id]).first
    unless @original_message
      halt 404, 'Ce message n\'existe pas !'
    end
    @received_message = ReceivedMessage.where('original_message_id = ? and account_id = ?', params[:message_id], @account.id).first
    @title = "Message du #{affiche_date_heure(@original_message[:sent_at], "à ")} pour #{@account.name}"
    render_message_calendar
    erb :'account/message.html'
  end

  ['/account/:name/:year/:month', '/account/:name/:year/:month/:day'].each do |path|
    get path do
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
      @show_days = true

      render_received_messages
    end
  end

  get '/account/:name' do
    @account = Account.where(:name => params[:name]).first

    unless @account
      halt 404, 'Ce compte n\'existe pas'
    end

    @title = @account.name
    @show_days = false

    original_messages = OriginalMessage.limit(100).order(:id.desc).limit(100)
    @original_messages_hash = {}
    if original_messages.empty?
      @received_messages = []
    else
      original_messages.each { |original_message| @original_messages_hash[original_message.id] = original_message }
      @received_messages = ReceivedMessage.where('original_message_id >= ?', @original_messages_hash.keys.sort.first).where(:account_id => @account.id).order(:original_message_id.asc)
    end

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
      @notification_mail = Meta.where(:name => 'notification_mail').first.andand.value
      erb :'admin/config.html'
    end
  end

  post '/config' do
    if check_logged
      ['email_from', 'email_to', 'email_subject', 'email_body', 'backend_password', 'notification_mail'].each do |key|
        if Meta.filter(:name => key).count == 0
          meta = Meta.new
          meta.name = key
          meta.value = params[key]
          meta.save
        else
          meta = Meta.where(:name => key).first
          meta.value = params[key]
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

  get '/reindex' do
    if check_logged
      original_messages = Hash.new { |hash, key| hash[key] = OriginalMessage.where(:id => key).first }
      modified_original_message_ids = []
      updated_messages_count = 0
      ReceivedMessage.all.each do |received_message|
        original_message = original_messages[received_message.original_message_id]

        mail = Mail.new(received_message.raw_content)
        received_at = mail[:received].collect { |received| DateTime.parse(received.value.split(';').last) }.max

        delay = (received_at.to_f - original_message.sent_at.to_f).to_i
        if delay != received_message.delay
          modified_original_message_ids << original_message.id
          updated_messages_count += 1
          received_message.delay = delay
          received_message.save
        end
      end
      update_original_messages_infos modified_original_message_ids
      flash[:notice] = "OK, #{updated_messages_count} message(s) réindexé(s)"
      redirect '/'
    end
  end

  private

  def original_message_calendar
    @calendar_min_date = OriginalMessage.order(:sent_at.asc).first.andand.sent_at
    @calendar_base_url = '/message/'
  end

  def render_original_messages
    @received_messages_per_id = {}
    ReceivedMessage.where(:id => @original_messages.collect { |om| om.slower_received_message_id }.compact).each do |received_message|
      @received_messages_per_id[received_message.id] = received_message
    end
    @accounts = Account.order(:name.asc)
    original_message_calendar
    erb :'index.html'
  end

  def render_message_calendar
    first_original_message = OriginalMessage.where('id = (select original_message_id from received_messages where account_id = ? ORDER BY original_message_id ASC LIMIT 1)', @account.id).first
    if first_original_message
      @calendar_min_date = first_original_message.sent_at
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