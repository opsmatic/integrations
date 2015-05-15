#!/usr/bin/env ruby
#
# opsmatic-zabbix.rb -- a script to relay zabbix triggered events to opsmatic
#
# You will need the following information:
#
# Opsmatic Organization Integration Token (Found in the Opsmatic dashboard under Org Settings | Team)
#
# See README.md for zabbix setup instructions
#
# Tested with all supported Rubies: 1.9.3, 2.0.0, 2.1.x

if RUBY_VERSION =~ /^1.8/
  require 'rubygems'
  require 'net/https'
end
require 'optparse'
require 'uri'
require 'net/http'
require 'json'
require 'date'

DEBUG_MODE    = false # set to true if debugging your Zabbix setup
CONN_TIMEOUT  = 2  # http connection timeout (seconds)
READ_TIMEOUT  = 2  # http read timeout (seconds)
DEFAULT_API_URL = "https://api.opsmatic.com/webhooks/events"

EVENT_TYPE_INDEX      = 0
HOST_INDEX            = 1
STATUS_INDEX          = 2
TRIGGER_NAME_INDEX    = 3

# map zabbix trigger severities to opsmatic statuses
status_map = {
  "OK"              => "ok",
  "PROBLEM"         => "failure",
  "Not Classified"  => "failure",
  "Information"     => "ok",
  "Warning"         => "warning",
  "Average"         => "failure",
  "High"            => "failure",
  "Disaster"        => "failure"
}

options = {
  :api_url => DEFAULT_API_URL
}

abort "Must supply three parameters: opsmatic-zabbix.rb to subject message" unless ARGV.length == 3

## Get command line parameters
# Message: Payload of data we parse
message = ARGV.pop

# Subject: Maps to basic metadata:
#   Message Subject: "Event: {HOST.HOST}: {TRIGGER.STATUS} : {TRIGGER.NAME}"
#   Recovery Subject: "Recovery: {HOST.HOST}: {TRIGGER.STATUS} : {TRIGGER.NAME}"
subject = ARGV.pop

# To: Opsmatic API Token
to = ARGV.pop

abort "Missing required parameters" unless message && subject && to

# Debugging -- useful if you aren't certain if you have configured Zabbix correctly.
# Uncomment and monitor your zabbix_server.log file.
if DEBUG_MODE
  $stderr.puts "To: #{to}"
  $stderr.puts "Subject: #{subject}"
  $stderr.puts "Message: #{message}"
end

# parse the subject
subject_data = subject.split(':').map{ |t| t.strip }
options[:token] = to
data = {
  :notification_type  => subject_data[EVENT_TYPE_INDEX],
  :notification_source=> "host",
  :notification_time  => Time.now.to_i,
  :host               => subject_data[HOST_INDEX],
  :status             => subject_data[STATUS_INDEX],
  :trigger_name       => subject_data[TRIGGER_NAME_INDEX]
}

if options[:token].nil?
  abort "Missing Opsmatic Token"
end

# parse the zabbix message body and capture each item into data
message.each_line do |line|
  key_value = line.split(':', 2)
  key = key_value.first.strip.downcase
  data[key] = key_value.last.strip
end

## postprocess the event
# Process timestamp
if data['event date']
  parse_date = data['event date'].split('.').map(&:to_i)
  parse_time = []
  if data['event time']
    parse_time = data['event time'].split(':').map(&:to_i)
  end

  data[:notification_time] = DateTime.new(parse_date[0], parse_date[1], parse_date[2],
                                          parse_time[0], parse_time[1], parse_time[2]).strftime("%s").to_i
end

# Override Opsmatic URL
if data['opsmatic api url']
  options[:api_url] = data['opsmatic api url']
end

summary = sprintf "%s with '%s' on %s (%s)",
  data[:notification_type],
  data[:trigger_name],
  data[:host],
  (data['trigger severity'] || data[:status])

event = {
  :timestamp    => data[:notification_time],
  :source       => "zabbix",
  :type         => "notifications/zabbix",
  :scopes       => {
    :hostname => data[:host]
  },
  :summary      => summary,
  :data         => data,
  :category     => "notifications",
  :status       => status_map[data[:status]]
}

# send the event
composed_uri = "#{options[:api_url]}?token=#{options[:token]}"
url = URI.parse(composed_uri)

http = Net::HTTP.new(url.host, url.port)
http.open_timeout = CONN_TIMEOUT
http.read_timeout = READ_TIMEOUT
http.use_ssl = (url.scheme == 'https')

request = Net::HTTP::Post.new(url.request_uri)
request["Content-Type"] = "application/json"
request.body = [event].to_json

$stderr.puts "URI: #{composed_uri} sending #{request.body}" if DEBUG_MODE

begin
  response = http.request(request)
  if response.code != "202"
    $stderr.puts "Got a #{response.code} from Opsmatic event service, notification wasn't recorded"
    $stderr.puts response.body
  else
    $stderr.puts "Success: Notified #{composed_uri}: #{summary} (#{data[:status]})"
  end
rescue Timeout::Error
  $stderr.puts "Timed out connecting to Opsmatic event service, notification wasn't recorded"
rescue Exception => msg
  $stderr.puts "An unhandled exception occured while posting event to Opsmatic event service: #{msg}"
end
