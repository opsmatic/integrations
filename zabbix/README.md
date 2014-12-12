# Zabbix Opsmatic Integration

The Opsmatic Zabbix integration allows you to have Zabbix triggered events added to your Opsmatic feed.

## Requirements

The Opsmatic Zabbix integration is written in Ruby, it should run out of the box on Ruby 1.9 and upwards. If you're still running Ruby 1.8.7 you'll need to ensure `rubygems` and the `json` gems are available.

## Configuration

1. Check your Ruby install:

    To check your Ruby version:

    `ruby -v`

    To install dependencies on Ubuntu:

    `sudo apt-get install ruby-json rubygems`

1. Install the `opsmatic-zabbix.rb` script in your Zabbix AlertScriptsPath directory on your Zabbix Server. See your Zabbix config documentation or zabbix_server.conf files for the exact location
on your system. The default for 2.2 is `/usr/local/share/zabbix/alertscripts`. For our examples we'll place the script in `/usr/local/share/zabbix/alertscripts/opsmatic-zabbix.rb`

1. Configure Zabbix Server to support Custom AlertScript media type. From your server's dashboard, go to `Administration | Media types`. Click `Create Media Type` button. Enter:

    2. Name: `Opsmatic Notification`
    2. Type: `Script`
    2. Script name: `opsmatic-zabbix.rb`
    2. Enabled: `on (check)`

1. Create a user for Opsmatic alerts. Go to `Administration | Users`, Switch dropdown to `Users` and click `Create User`.

    ### User Tab

    2. Set the `Alias` to `Opsmatic` and `Name` to `Opsmatic Notifier`.
    2. The `password` is any safe value you choose.
    2. The `group` doesn't matter, but we use the default `No access to the frontend`.
    2. The `Permissions` need to be read-write for any areas that will have the action triggered. In a default install, this is usually captured in a `Zabbix Super Admin` group, but you may have a custom setup.

    ### Media Tab

    2. Set the `type` to `Opsmatic Notification`.
    2. Set `Send to` to your `Opsmatic API Token`.
    2. Leave the other fields as default (24x7 active and all severities).
    2. Make sure the `Status` is `enabled`.

1. Configure Zabbix Server Action to initiate communication with Opsmatic. From your server's dashboard, go to `Configuration | Actions`. Select the `Event source` to be `Triggers`. Click `Create action` button. Enter:

    ### Action Tab

    ```
    Name: Opsmatic Notifier

    Default subject: Event: {HOST.HOST}: {TRIGGER.STATUS} : {TRIGGER.NAME}

    Default message:
        Trigger: {TRIGGER.NAME}
        Trigger Status: {TRIGGER.STATUS}
        Trigger Severity: {TRIGGER.SEVERITY}
        Trigger NSeverity: {TRIGGER.NSEVERITY}
        Trigger Expression: {TRIGGER.EXPRESSION}
        Host Name: {HOST.NAME}
        Host: {HOST.HOST}
        Host IP: {HOST.IP}
        Event ID: {EVENT.ID}
        Event value: {EVENT.VALUE}
        Event status: {EVENT.STATUS}
        Event time: {EVENT.TIME}
        Event date: {EVENT.DATE}
        Event age: {EVENT.AGE}
        Event acknowledgement: {EVENT.ACK.STATUS}
        Event acknowledgement history: {EVENT.ACK.HISTORY}

    Recovery message: on (check)

    Recovery subject: Recovery: {HOST.HOST}: {TRIGGER.STATUS} : {TRIGGER.NAME}

    Recovery message:
        Trigger: {TRIGGER.NAME}
        Trigger Status: {TRIGGER.STATUS}
        Trigger NSeverity: {TRIGGER.NSEVERITY}
        Trigger Severity: {TRIGGER.SEVERITY}
        Trigger Expression: {TRIGGER.EXPRESSION}
        Host Name: {HOST.NAME}
        Host: {HOST.HOST}
        Host IP: {HOST.IP}
        Event ID: {EVENT.ID}
        Event value: {EVENT.VALUE}
        Event status: {EVENT.STATUS}
        Event time: {EVENT.TIME}
        Event date: {EVENT.DATE}
        Event age: {EVENT.AGE}
        Event acknowledgement: {EVENT.ACK.STATUS}
        Event acknowledgement history: {EVENT.ACK.HISTORY}
        Event Recovery ID: {EVENT.RECOVERY.ID}
        Event Recovery value: {EVENT.RECOVERY.VALUE}
        Event Recovery status: {EVENT.RECOVERY.STATUS}
        Event Recovery time: {EVENT.RECOVERY.TIME}
        Event Recovery date: {EVENT.RECOVERY.DATE}

    Enabled: on (check)
    ```

    ### Conditions Tab (dependent on your Zabbix Version)

    2. Set your conditions as following:

        ```
        (A) Maintenance status not in maintenance
        (B) Trigger value = PROBLEM
        (C) Trigger value = OK
        ```
    2. Make sure the type of calculation is (A) and (B or C)

    ### Operations Tab

    2. Create a new `Operation`, selecting defaults.
    2. Operations type should be `Send message`.
    2. For Send to Users, select your `Opsmatic user`.
    2. Select `Opsmatic Notification` from the `Send only to` dropdown and be sure the `Default message`
    checkbox is checked.
    2. Click `Add` to add your new operation.

1. You can check your configuration by looking at the Event list in your Zabbix dashboard, and
clicking on an individual Event's timestamp (detail view). There should be no errors. You can
also review your `zabbix_server.log` file for diagnostics. If you need additional help and logging
information, you can change the `DEBUG_MODE` constant in the `opsmatic-zabbix.rb` script to `true`.
