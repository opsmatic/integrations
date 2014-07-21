# Nagios Opsmatic Integration

The Opsmatic Nagios integration allows you to have Nagios report host and service notifications to your Opsmatic feed.

## Requirements

The Opsmatic Nagios integration is written in Ruby, it should run out of the box on Ruby 1.9 and upwards. If you're still running Ruby 1.8.7 you'll need to ensure `rubygems` and the `json` gems are available.

## Configuration

1. Install the `opsmatic-nagios.rb` script in your directory of choice. For our examples we'll place it in `/usr/local/bin/opsmatic-nagios.rb`

1. Define a new command in your Nagios configuration:

        define command {
            command_name    notify-via-opsmatic
            command_line    /usr/local/bin/opsmatic-nagios.rb --token <your_integration_token>
        }
   
    You'll need to add your Opsmatic integration token to the `--token` command like parameter, you'll find that on your account settings page.

1. Define a new contact in your Nagios configuration:

        define contact {
            contact_name                     opsmatic
            alias                            Opsmatic
            service_notification_commands    notify-via-opsmatic
            host_notification_commands       notify-via-opsmatic
            service_notification_period      24x7
            host_notification_period         24x7
            service_notification_options     w,u,c,r
            host_notification_options        d,r
        }
		
    Depending on your configuration you may need to adjust those parameters slightly to suit your environment. The configuration listed above assumes you have a `24x7` time period defined, and that you are happy with all service and host notification types being sent to Opsmatic.
	
1. Add the newly defined `opsmatic` contact to your appropriate contact groups, or directly to hosts and services that you wish you publish notifications for to Opsmatic

1. Restart Nagios and you're up and running!

## Advanced Configuration

To allow us to correlate Nagios events to hosts within your infrastructure that have an Opsmatic agent installed we need to know which field in your Nagios host configuration contains the host's FQDN.

A Nagios host configuration allows you to specify a `name` and `alias` there is no requirement that either field contain an FQDN so it is largely dependent on how your own "house standard" is defined.

If your Nagios host `name` contains the FQDN, there's no changes required - by default we'll match a Nagios host name against your installed agents. If however you store the FQDN in the host `alias` field you'll need to add the following command line parameter to the notification command configuration:

    --hostname_pref alias
    
So for example an Opsmatic notification command configuration to use the alias field would look a little like:

        define command {
            command_name    notify-via-opsmatic
            command_line    /usr/local/bin/opsmatic-nagios.rb --token <your_integration_token> --hostname_pref alias
        }