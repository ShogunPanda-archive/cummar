#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "yaml"
require "fileutils"
require "active_support/core_ext"
require "moneta"

require "omniauth-facebook"
require "omniauth-twitter"
require "omniauth-linkedin"
require "omniauth-google-oauth2"
require "omniauth-instagram"

require "koala"
require "twitter"
require "linkedin"
require "google/api_client"
require "instagram"

require "sinatra/base"
require "slim"
require "compass"
require "coffee-script"

require_relative "cummar/version" if !defined?(Cummar::Version)
require_relative "cummar/local_contact"
require_relative "cummar/remote_contact"
require_relative "cummar/providers/base"
require_relative "cummar/providers/facebook"
require_relative "cummar/providers/twitter"
require_relative "cummar/providers/linkedin"
require_relative "cummar/providers/google_plus"
require_relative "cummar/providers/instagram"
require_relative "cummar/providers/local"
require_relative "cummar/server"