DREDD: Let me judge your mails!

A tool to check on mailing lists health.

When you operate a mailing list server, you may want to time how long the messages take to reach the most common email providers. This enables you to detect any problem on a server, or with a specific provider. This simple tool should fulfill this requirement.

It is written in ruby, and requires basic ruby knowledge to install and customize it.

The code is pretty simple and should be easy to hack on. Contact me if you have any question.

# How it works:
Create a specific mailing list (e.g. dredd@rezo.net) and an account for each mail provider you want to watch. Subscribe each of them to the dredd list. A background task must be set up, which will send mails to the mailing list. Another task will connect to each account and fetch the resulting messages. The result are displayed on a webapp. When emails are late, the system generates twitter messages on an account that the server admin will follow.

# Installation

- checkout the code
- install the bundler gem
- in the checkout directory run `bundle install`
- (optional) change the database url in the `config.ru` file, by default a `dredd.sqlite3` sqlite database will be used
- in the checkout directory, run `rackup`
- open your browser on <http://localhost:9292>

# Configuration

- Connect to the database and add a user (dredd admin) by adding her OpenID identifier:
`insert into users (openid_identifier) values ('http://XXXXXX.myopenid.com/');`
- Connect to <http://localhost:9292/config> for the mail configuration and pick a backend password for the background tasks (see below)
- Connect to  <http://localhost:9292/admin> and add some email accounts
- cron a http request to <http://localhost:9292/backend_send_mail/XXX> (where `XXX` is the backend password) to send the mails to the list
- cron a http request to <http://localhost:9292/backend_check_mail/XXX> (where `XXX` is the backend password) to fetch the mails from each account

# Dependencies

- the sinatra web framework <http://www.sinatrarb.com/>
- the sequel database toolkit <http://sequel.rubyforge.org/>
- the mail gem <http://github.com/mikel/mail/>
- the jQuery javascript framework <http://jquery.com/>
- the Flot javascript plotting library <http://code.google.com/p/flot/>

# License

Each library has its own license; the content developped specifically for this site is (c) Julien Kirch 2010 and licensed under the MIT license.

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.