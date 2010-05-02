require 'sinatra/base'

module Sinatra
  
  module DreddHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def input_text(name, label, value)
      "<p>
      <label for=\"#{name}\">#{label}</label>
      <input id=\"#{name}\" name=\"#{name}\" type=\"text\" value=\"#{value}\"/>
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
      <label for=\"#{name}\">#{label}</label>
      <textarea id=\"#{name}\" name=\"#{name}\" cols=\"#{cols}\" rows=\"#{rows}\">#{value}\"</textarea>
  </p>"
    end

  end

  helpers DreddHelper
  
end
