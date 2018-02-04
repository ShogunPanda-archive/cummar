#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

framework "AddressBook"
require "yaml"
require "fileutils"
require File.dirname(__FILE__) + "/./local_contact"

module Cummar
  ROOT = File.dirname(__FILE__) + "/../../"
  CONFIGURATION = YAML.load_file(ROOT + "/config.yml")
  TMPDIR = "/tmp/cummar"
  BIRTHDAY_NULL_YEAR = 1604

  class Helper
    def data
      @data ||= YAML.load_file(Cummar::TMPDIR + "/updates.yml")
    end

    def updates
      @updates ||= data[:updates]
    end

    def records
      @records ||= data[:records]
    end

    def save
      provider = ARGV[1]

      puts "Starting updates of contacts ..."

      Cummar::LocalContact.load_addressbook(address_book, false).each do |id, contact|
        update_contact(contact, updates[id]) if updates[id]
      end

      address_book.save
      puts "Operation completed."
    end

    def update_contact(contact, update)
      puts "  Updating #{contact.full_name} ..."

      ["social", "website", "photo", "birthday"].each do |field|
        key, value = parse_field(provider, field, update[field])

        if value then
          puts "    Updating #{format_field(key)} to be \"#{format_value(field, value)}\" ..."
          contact.send("update_#{field}", self, value, provider)
        end
      end
    end

    def load
      puts Cummar::LocalContact.load_addressbook(ABAddressBook.addressBook, true).to_yaml
    end

    private
      def address_book
        @address_book ||= ABAddressBook.sharedAddressBook
      end

      def parse_field(provider, field, value)
        key = field == "social" ? provider : field
        value = Date.parse(value, "%F") if value && field == "birthday"

        [key, value]
      end

      def format_field(field)
        case field
          when "linkedin" then "LinkedIn"
          when "google-plus" then "Google+"
          else field.capitalize
        end
      end

      def format_value(field, value)
        field == "birthday" ? value.strftime(value.year == Cummar::BIRTHDAY_NULL_YEAR ? "%d %B" : "%d %B %Y") : value
      end
  end
end

Cummar::Helper.new.send(ARGV[0] == "save" ? :save : :load)