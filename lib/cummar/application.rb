#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  class Application
    def self.run
      new.execute
    end

    def execute
      FileUtils.mkdir_p("/tmp/cummar")

      Cummar::LocalContact.load_addressbook(address_book).each do |contact|
        puts "[#{contact.id}] #{contact.to_s(true)}"
      end

      #FileUtils.rm_rf("/tmp/cummar")
    end

    def address_book
      @address_book ||= ABAddressBook.addressBook
    end
  end
end