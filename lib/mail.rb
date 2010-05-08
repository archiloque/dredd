require 'sinatra/base'
require 'mail'
require 'net/pop'
require 'date'

class Time
  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.civil(year, month, day, hour, min, seconds, offset)
  end
end

module Sinatra

  module DreddMailHelper

    MESSAGE_ID_REGEXP = /(\d+)@dredd.listes.rezo.com/

    def check_accounts accounts
      found_messages = 0
      exception_message = ''
      original_messages = Hash.new{ |hash, key| hash[key] = OriginalMessage.where(:sent_at => key).first }
      accounts.each do |account|
        begin
          pop3(account) do |pop|
            pop.each_mail do |m|
              raw_content = m.pop
              mail = Mail.new(raw_content)
              # does the message id match our regexp ?
              match = MESSAGE_ID_REGEXP.match(mail.message_id)
              if match
                timestamp_value = Time.at(match[1].to_i).to_datetime

                # look for the original message
                original_message = original_messages[timestamp_value]
                if original_message && (ReceivedMessage.where(:account_id => account.id).where(:original_message_id => original_message.id).count == 0)
                  received_message = ReceivedMessage.new
                  received_message.original_message = original_message
                  received_message.account = account
                  received_message.raw_content = raw_content
                  received_message.received_at = DateTime.parse(mail[:received][0].value.split(';').last)
                  received_message.delay = (received_message.received_at.to_f - original_message.sent_at.to_f).to_i
                  received_message.save
                  found_messages += 1
                end
              end
            end
          end
          account.update_after_connection true
        rescue Exception => e
          account.update_after_connection false, error_2_text(e)
          exception_message << error_2_html(e)
        end
      end
      if exception_message != ''
        raise exception_message
      else
        found_messages
      end
    end

    def send_message original_message
      mail = Mail.new do
        from original_message.from
        to original_message.to
        subject original_message.subject
        body original_message.body
        message_id "<#{original_message.sent_at.to_i}@dredd.listes.rezo.com>"
      end
      mail.delivery_method :sendmail
      mail.deliver
    end

    private

    def pop3 account, & b
      pop = Net::POP3.new(account.server_address, account.port)
      if account.ssl
        pop.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      end
      pop.start(account.address, account.password, & b)
    end
  end

  helpers DreddMailHelper

end
