#!/usr/bin/python

###############################################################################
# This script 
#
# Copyright (c) 2017 Raymond McCrae
# Created 20 Dec 2017
###############################################################################

import os, subprocess, re, fnmatch, time

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
	for file in files:
		filename = file["name"]
		mtime = get_mtime(file)
		#print filename
		timestamp = time.strftime("%b %d %Y %H:%M:%S", time.gmtime(mtime))
		match = device_regex.search(filename)
		if match:
			#print "match"
			device_id = match.group("deviceid")
			#print device_id
			if device_id in devicemap:
				device_name = devicemap[device_id]
			else:
				device_name = "Unknown Device %s" % device_id
			print timestamp + " - " + device_name

#print device_map()
files = find_files("/Users/raymond/Library/Developer/CoreSimulator/Devices", "CoreDataDemo.sqlite")
get_details_for_databases(files)

