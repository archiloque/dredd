ENV['DATABASE_URL'] = 'mysql://dredd:judge@localhost/dredd'
require './dredd'
run Dredd
