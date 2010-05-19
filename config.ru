ENV['DATABASE_URL'] = "sqlite://dredd.sqlite3"
require 'dredd'
run Dredd
