#!/usr/bin/python

import subprocess, re

def device_map():
	device_map = { }
	device_regex = re.compile(r"^(?P<devicename>[^\[]+?) \[(?P<deviceid>[A-Z0-9-]+)\].*")
	stream = subprocess.Popen("xcrun instruments -s devices", shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	for line in stream.stdout.readlines():
		match = device_regex.match(line)
		if match:
			device_name = match.group("devicename")
			device_id = match.group("deviceid")
			device_map[device_id] = device_name
	return_value = stream.wait()
	return device_map

print device_map()
