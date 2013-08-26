#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

framework "AddressBook"
basepath = File.dirname(__FILE__)

require "rubygems"
require "active_support/all"
require "tempfile"

require basepath + "/cummar/contact"
require basepath + "/cummar/local_contact"
require basepath + "/cummar/application"

