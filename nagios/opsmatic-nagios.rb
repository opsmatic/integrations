#!/usr/bin/env ruby

if RUBY_VERSION =~ /^1.8/
  require 'rubygems'
  require 'net/https'
end
require 'optparse'
require 'uri'
require 'net/http'
require 'json'

CONN_TIMEOUT = 2  # http connection timeout (seconds)
READ_TIMEOUT = 2  # http read timeout (seconds)
DEFAULT_API_URL = "https://api.opsmatic.com/webhooks/events"

# map nagios statuses to opsmatic statuses
status_map = {
  # host states
  "UP"       => "ok",
  "DOWN"     => "failure",
  # service states
  "OK"       => "ok",
  "WARNING"  => "warning",
  "CRITICAL" => "failure",
  "UNKNOWN"  => "warning"
}

## process command line
options = {
  :api_url => DEFAULT_API_URL,
  :name_pref => "name",
}

OptionParser.new do |opts|
  opts.on "-t", "--token TOKEN", "Opsmatic Integration Token" do |token|
    options[:token] = token
  end
  opts.on "-u", "--url URL", "Opsmatic API URL (default: #{options[:api_url]})" do |url|
    options[:api_url] = url
  end
  opts.on "-n", "--hostname_pref NAME_PREF", "Which Nagios field to use for hostname 'name' or 'alias'" do |name_pref|
    options[:name_pref] = name_pref.downcase
  end
end.parse!

if !options.has_key?(:token)
  abort "ERROR: you must provide your opsmatic integration token with the --token parameter"
end

if options[:name_pref] !~ /name|alias/
  abort "ERROR: hostname prefernce must be 'name' or 'alias'"
end

# cherry pick the nagios details we need
data = {
  :notification_type => ENV['NAGIOS_NOTIFICATIONTYPE'],
  :notification_time => ENV['NAGIOS_TIMET'].to_i,
  :host => {
    :name        => ENV['NAGIOS_HOSTNAME'],
    :alias       => ENV['NAGIOS_HOSTALIAS'],
    :address     => ENV['NAGIOS_HOSTADDRESS'],
    :state       => ENV['NAGIOS_HOSTSTATE'],
    :output      => ENV['NAGIOS_HOSTOUTPUT'],
  },
  :service => {
    :desc        => ENV['NAGIOS_SERVICEDESC'],
    :state       => ENV['NAGIOS_SERVICESTATE'],
    :output      => ENV['NAGIOS_SERVICEOUTPUT'],
  },
}

## process the event
# no service state, we must be a host event
event = {
  :timestamp    => data[:notification_time],
  :source       => "nagios",
  :type         => "notifications/nagios",
  :data         => {},
  :scopes       => {
    :hostname => options[:name_pref] == "name" ? data[:host][:name] : data[:host][:alias]
  }
}

# if we have service state we're a service event
if not data[:service][:state].empty?
  event[:summary] = sprintf "%s with '%s' on %s (%s)",
    data[:notification_type],
    data[:service][:desc],
    event[:subject],
    data[:service][:state]
  event[:data][:notification_type]   = data[:notification_type]
  event[:data][:notification_source] = "service"
  event[:data][:service] = data[:service]
  event[:status] = status_map[data[:service][:state]]
  event[:category] = "notifications"
else
  # we're a host event
  event[:summary] = sprintf "%s on %s (%s)",
    data[:notification_type],
    event[:subject],
    data[:host][:state]
  event[:data][:notification_type]   = data[:notification_type]
  event[:data][:notification_source] = "host"
  event[:data][:host] = data[:host]
  event[:status] = status_map[data[:host][:state]]
  event[:category] = "notifications"
end

# send the event
url = URI.parse("#{options[:api_url]}?token=#{options[:token]}")

http = Net::HTTP.new(url.host, url.port)
http.open_timeout = CONN_TIMEOUT
http.read_timeout = READ_TIMEOUT
http.use_ssl = (url.scheme == 'https')

request = Net::HTTP::Post.new(url.request_uri)
request["Content-Type"] = "application/json"
request.body = [event].to_json

begin
  response = http.request(request)
  if response.code != "202"
    puts "Got a #{response.code} from Opsmatic event service, notification wasn't recorded"
    puts response.body
  end
rescue Timeout::Error
  puts "Timed out connecting to Opsmatic event service, notification wasn't recorded"
rescue Exception => msg
  puts "An unhandled execption occured while posting event to Opsmatic event service: #{msg}"
end
