#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  module Providers
    class Instagram < Base
      def supported_fields
        ["social", "website", "photo"]
      end

      def has_authentication_data?
        configuration["token"].present?
      end

      def save_authentication(auth_data)
        configuration["token"] = auth_data["credentials"]["token"]
        save_configuration("instagram", configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            contacts = []
            cursor = ""

            while cursor do
              follows = client.user_follows(nil, cursor: cursor, count: 100)
              contacts += follows
              cursor = follows.pagination.next_cursor
            end

            @contacts = sort(contacts.map{|follow| build_contact(follow)})

            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(::Instagram::Error)
          raise e
        end
      end

      def profile_for(contact)
        "http://www.instagram.com/#{contact.nick}"
      end

      private
        def client
          ::Instagram.client(access_token: configuration["token"])
        end

        def build_contact(user)
          name = user["full_name"]
          name = user["username"] if name.blank?
          Cummar::RemoteContact.new(user, "instagram", user["id"], name, user["username"], user["website"], user["profile_picture"])
        end

        def clear_authentication
          configuration["token"] = ""
          save_configuration("instagram", configuration)
        end
    end
  end
end