require 'sinatra/base'
require 'mail'

module Sinatra

  module DreddMailHelper

    def test_account account
      create_pop3(account).last
    end

    private

    def create_pop3 account
      Mail::POP3.new({:address => account.server_address,
                      :user_name => account.address,
                      :password => account.password,
                      :port => account.port,
                      :enable_ssl => account.ssl})
    end
  end

  helpers DreddMailHelper

end
