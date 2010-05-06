require 'sinatra/base'
require 'mail'
require 'net/pop'

module Sinatra

  module DreddMailHelper

    def test_account account
      pop3(account) do |pop|
        pop.n_mails
      end
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

    def pop3 account, &b
      pop = Net::POP3.new(account.server_address, account.port)
      if account.ssl
        pop.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      end
      pop.start(account.address, account.password, &b)
    end
  end

  helpers DreddMailHelper

end
