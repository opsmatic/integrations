import subprocess, json
from os import environ
import os
import time
import urllib2

from ansible.constants import p, get_config
from ansible import utils

class CallbackModule(object):
	def __init__(self):
		self.opsmatic_http = get_config(p, "opsmatic", "opsmatic_http", "OPSMATIC_API_HTTP", "https://api.opsmatic.com")
		self.token = get_config(p, "opsmatic", "integration_token", "OPSMATIC_INTEGRATION_TOKEN", "")
		self.have_creds = self.token != ""
		if not self.have_creds:
			utils.warning("Opsmatic token is not set, so no events will be sent."
					  "It can be set via the `integration_token` varibale in the [opsmatic] section of ansible.cfg"
					  "OR via the OPSMATIC_INTEGRATION_TOKEN environment variable")

	def _opsmatic_event(self, summary, body, event_type, category, status=None, host=None, handler=None, source=None):
		if self.have_creds:
			event = {
				"category": category,
				"summary": summary,
				"data": body,
				"type": event_type,
				"timestamp": int(time.time())
			}

			if source:
				event["source"] = source
			else:
				event["source"] = "ansible-callback"

			if status:
				event["status"] = status
			if host:
				event["subject_type"] = "hostname"
				event["subject"] = host
	
			data = [event]
			url = "%s/webhooks/events" % self.opsmatic_http
			if handler:
				data = data[0]
				url += "/%s" % handler
	
			url += "?token=%s" % self.token

			out = ""
			req = urllib2.Request(url, json.dumps(data), {'Content-Type': 'application/json'})
			response = urllib2.urlopen(req, None, 2)
			
	def playbook_on_start(self):
		self.start = int(time.time())

	def playbook_on_play_start(self, name):
		self.playbook_name, _ = os.path.splitext(
				                os.path.basename(self.play.playbook.filename))

	def playbook_on_stats(self, stats):
		try:
			# report final event on a per-host basis
			hosts = sorted(stats.processed.keys())
			summary = "Ansible playbook '%s' applied by %s" % (self.playbook_name, self.playbook.remote_user)
			for host in hosts:
				body = stats.summarize(host)
				body["start_time"] = self.start
				body["end_time"] = int(time.time())
				body["remote_user"] = self.playbook.remote_user
				body["playbook_name"] = self.playbook_name
				host_summary = summary
				status = ""
				if body["failures"] > 0:
					status = "failure"
				self._opsmatic_event(summary, body, "ansible/playbook_on_stats", "automation", host=host, handler="ansible", source="cm_raw", status=status)
		except Exception, e:
			utils.err("Error posting stats event to opsmatic: %s" % e)
