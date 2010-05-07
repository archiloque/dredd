require 'sinatra/base'

class Object
  # An object is blank if it's false, empty, or a whitespace string.
  # For example, "", "   ", +nil+, [], and {} are blank.
  #
  # This simplifies:
  #
  #   if !address.nil? && !address.empty?
  #
  # ...to:
  #
  #   if !address.blank?
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

module Sinatra

  module DreddHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def value(label, value)
      "<p>
      <label>#{label}</label>: #{value}
  </p>"
    end

    def value_under(label, value)
      "<p>
      <label>#{label}</label><div class=\"bordered\">#{value}</div>
  </p>"
    end

    def value_checkbox(label, value)
      "<p>
      <label>#{label}</label> 
      <input name=\"#{label}\" type=\"checkbox\"#{value ? ' checked="checked"' : ''}\" disabled=\"true\"/>
  </p>"
    end

    def input_text(name, label, value, size = nil)
      "<p>
      <label for=\"#{name}\">#{label}</label>
      <input id=\"#{name}\" name=\"#{name}\" type=\"text\" value=\"#{value}\"#{size ? " size=\"#{size}\"" : ''}/>
  </p>"
    end

    def input(name, label, value, type)
      "<p>
      <label for=\"#{name}\">#{label}</label>
      <input id=\"#{name}\" name=\"#{name}\" type=\"#{type}\" value=\"#{value}\"/>
  </p>"
    end

    def input_checkbox(name, label, value)
      "<p>
      <label for=\"#{name}\">#{label}</label>
      <input id=\"#{name}\" name=\"#{name}\" type=\"checkbox\"#{value ? ' checked="checked"' : ''}\"/>
  </p>"
    end

    def input_text_area(name, label, value, cols, rows)
      "<p>
      <label for=\"#{name}\">#{label}</label><br/>
      <textarea id=\"#{name}\" name=\"#{name}\" cols=\"#{cols}\" rows=\"#{rows}\">#{value}</textarea>
  </p>"
    end

    def affiche_date date
      if date
        date.strftime('%d/%m/%Y')
      end
    end

    def affiche_date_heure date
      if date
        date.strftime('%d/%m/%Y %H:%M:%S')
      end
    end

    def error_2_text e
      ([e.class, e.message] + e.backtrace).join("\n")
    end

    def error_2_html e
      ([e.class, e.message] + e.backtrace).join('<br/>') + '<br/>'
    end

    def error_text_2_html e
      e.gsub "\n", "<br/>"
    end

  end

  helpers DreddHelper

end
