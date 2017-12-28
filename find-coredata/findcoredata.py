#!/usr/bin/python

#################################################################################
# This script searches for SQLite database files within the simulator directories
# and list the 5 most recent database files by modification time.
#
# Copyright (c) 2017 Raymond McCrae
# Created 20 Dec 2017
#################################################################################

import os, subprocess, re, fnmatch, time, sys

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

def find_files(rootdir, pattern):
	matched_files = [ ]
	for root, dirs, files in os.walk(rootdir):
		for name in files:
			if fnmatch.fnmatch(name, pattern):
				matched_files.append(os.path.join(root, name))
	return matched_files

def get_file_modified_times(filenames):
	files = [ ]
	for filename in filenames:
		stat = os.stat(filename)
		mtime = stat.st_mtime
		files.append({"name" : filename, "mtime" : mtime})
	return sorted(files, key=get_mtime, reverse=True)

def get_mtime(item):
	return item["mtime"]

def get_details_for_databases(database_files):
	devicemap = device_map()
	device_regex = re.compile(r"/CoreSimulator/Devices/(?P<deviceid>[A-Z0-9-]+)/")
	files = get_file_modified_times(database_files)
	index = 0
	for file in files[0:5]:
		filename = file["name"]
		mtime = get_mtime(file)
		timestamp = time.strftime("%b %d %Y %H:%M:%S", time.gmtime(mtime))
		match = device_regex.search(filename)
		if match:
			device_id = match.group("deviceid")
			if device_id in devicemap:
				device_name = devicemap[device_id]
			else:
				device_name = "Unknown Device %s" % device_id
			index = index + 1
			print str(index) + " : " + timestamp + " - " + device_name + " - " + os.path.basename(filename)
	print "0 : Exit"
	return files[0:5]

homedir = os.environ['HOME']
devicesdir = os.path.join(homedir, "Library/Developer/CoreSimulator/Devices")
for arg in sys.argv[1:]:
	files = find_files(devicesdir, arg)
	databases = get_details_for_databases(files)
	choice = int(raw_input("Enter your choice: "))
	if choice > 0:
		database = databases[choice - 1]
		filename = database["name"]
		os.system("sqlite3 \"" + filename + "\"")
