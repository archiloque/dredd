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

    ONE_MINUTE = 1.0 / (24 * 60)

    GMT_TIMEZONE = TZInfo::Timezone.get('GMT')

    def check_accounts accounts
      found_messages = 0
      exception_message = ''
      original_messages = Hash.new { |hash, key| hash[key] = OriginalMessage.where(:sent_at => key).first }
      accounts.each do |account|
        begin
          pop3(account) do |pop|
            pop.each_mail do |m|
              raw_content = m.pop
              mail = Mail.new(raw_content)
              # does the message id match our regexp ?
              match = MESSAGE_ID_REGEXP.match(mail.message_id)
              if match
                timestamp_value = timestamp_2_datetime(match[1])

                # look for the original message
                original_message = original_messages[timestamp_value]
                if original_message && (ReceivedMessage.where(:account_id => account.id).where(:original_message_id => original_message.id).count == 0)
                  received_message = ReceivedMessage.new
                  received_message.original_message = original_message
                  received_message.account = account
                  received_message.raw_content = raw_content
                  received_message.received_at = mail[:received].collect { |received| DateTime.parse(received.value.split(';').last) }.max
                  received_message.delay = (received_message.received_at.to_f - original_message.sent_at.to_f).to_i
                  received_message.save
                  found_messages += 1
                end
              end
              if ENV['delete_mails']
                m.delete
              end
            end
          end
          account.update_after_connection true
        rescue Exception => e
          account.update_after_connection false, error_2_text(e)
          exception_message << error_2_html(e)
        end
      end
      update_original_messages_infos original_messages.values.compact.collect { |original_message| original_message.id }

      message = nil
      now = DateTime.now
      missing_message = OriginalMessage.where('median_time_to_receive is null and sent_at < ? and sent_at > ?', (now - (10 * ONE_MINUTE)), (now - (120 * ONE_MINUTE))).order(:sent_at.asc).first
      if missing_message
        message = "[dredd] Le message de #{affiche_date_heure(GMT_TIMEZONE.utc_to_local(missing_message.sent_at))} GMT n'est toujours arrive dans aucune boite mail"
      else
        late_message = OriginalMessage.where('median_time_to_receive > 600 and sent_at < ? and sent_at > ?', (now - (10 * ONE_MINUTE)), (now - (120 * ONE_MINUTE))).order(:sent_at.asc).first
        if late_message
          message = "[dredd] Le message de #{affiche_date_heure(GMT_TIMEZONE.utc_to_local(late_message.sent_at))} GMT a une mediane de #{late_message.median_time_to_receive.to_i}s"
        end
      end
      if message
        mail = Mail.new do
          from Meta.where(:name => 'email_from').first.andand.value
          to Meta.where(:name => 'notification_mail').first.andand.value
          subject message
          body message
        end
        mail.delivery_method :sendmail
        mail.deliver
      end
      if exception_message != ''
        raise exception_message
      else
        found_messages
      end

    end

    def create_message
      from = Meta.where(:name => 'email_from').first.andand.value
      to = Meta.where(:name => 'email_to').first.andand.value
      subject = Meta.where(:name => 'email_subject').first.andand.value
      body = Meta.where(:name => 'email_body').first.andand.value
      if (from && to && subject && body)
        message = OriginalMessage.new
        message.from = from
        message.to = to
        message.subject = subject
        message.body = body
        d = DateTime.now
        message.sent_at = DateTime.civil(d.year, d.month, d.day, d.hour, d.min, d.sec, d.offset)
        message
      else
        nil
      end
    end

    def send_message original_message
      mail = Mail.new do
        from original_message.from
        to original_message.to
        subject original_message.subject
        body original_message.body
        message_id "<#{Integer(original_message.sent_at.to_f)}@dredd.listes.rezo.com>"
      end
      mail.delivery_method :sendmail
      mail.deliver
    end

    def update_original_messages_infos original_messages_ids
      unless original_messages_ids.empty?
        database.run("update original_messages
                    set slower_received_message_id =
                      (select received_messages.id from received_messages
                        where original_messages.id = received_messages.original_message_id order by received_messages.delay desc limit 1)
                    where id in (#{original_messages_ids.uniq.join(', ')})")
        original_messages_ids.uniq.each do |original_message_id|
          original_message = OriginalMessage.where(:id => original_message_id).first
          original_message.median_time_to_receive = ReceivedMessage.order(:delay.asc).where('original_message_id = ?', original_message_id).collect { |received_message| received_message.delay }.median
          original_message.save
        end
      end
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
