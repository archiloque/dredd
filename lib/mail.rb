require 'sinatra/base'
require 'mail'

module Sinatra

  module DreddMailHelper

    def test_account account
      create_pop3(account).last
    end

    def send_message original_message
      mail = Mail.new do
        from original_message.from
        to original_message.to
        subject original_message.subject
        body original_message.body
        message_id "<#{original_message.created_at.to_i}@dredd.listes.rezo.com>"
      end
      mail.delivery_method :sendmail
      mail.deliver
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
