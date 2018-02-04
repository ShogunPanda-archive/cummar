#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Cummar
  module Providers
    class Local < Base
      def contacts
        @contacts = read_cache

        if !@contacts then
          contacts = YAML.load(%x[macruby "#{helper_path}" load])
          @contacts = contacts.map {|id, record| Cummar::LocalContact.new(record.merge(id: id)) }
          write_cache(@contacts)
        end

        @contacts
      end

      def update(provider, updates)
        updates = JSON.parse(updates) rescue {}

        FileUtils.mkdir_p(Cummar::TMPDIR)
        File.open(Cummar::TMPDIR + "/updates.yml", "w") {|f|
          f.write({updates: updates, records: Cummar::Server.cache[provider][:data]}.to_yaml)
        }

        %x[macruby "#{helper_path}" save #{provider}]
      end

      private
        def helper_path
          File.dirname(__FILE__) + "/../helper.rb"
        end
    end
  end
end