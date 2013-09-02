#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  module Providers
    class Facebook < Base
      def has_authentication_data?
        configuration["token"].present?
      end

      def save_authentication(auth_data)
        configuration["token"] = auth_data["credentials"]["token"]
        save_configuration("facebook", configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            client = get_client
            contacts = []
            offset = 0
            limit = 100

            while offset do
              friends = client.get_connection("me", "friends", {offset: offset, limit: limit}).map {|friend| friend["id"] }

              if friends.present? then
                contacts += friends
                offset += limit
              else
                offset = nil
              end
            end

            @contacts = sort(client.get_objects(contacts, {fields: "id,name,username,birthday,picture.type(large),website"}).map {|_, friend|
              build_contact(friend)
            })

            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(Koala::Facebook::AuthenticationError)
          raise e
        end
      end

      def profile_for(contact)
        "http://www.facebook.com/#{contact.nick}"
      end

      private
        def get_client
          Koala::Facebook::API.new(configuration["token"])
        end

        def build_contact(user)
          Cummar::RemoteContact.new(
            user, "facebook", user["id"], user["name"], user["username"], user["website"],
            user["picture"]["data"]["url"], parse_birthday(user["birthday"])
          )
        end

        def parse_birthday(birthday)
          if birthday.present? then
            birthday += "/#{Cummar::BIRTHDAY_NULL_YEAR}" if birthday =~ /^\d{2}\/\d{2}$/
            Date.strptime(birthday, "%m/%d/%Y")
          else
            nil
          end
        end

        def clear_authentication
          configuration["token"] = ""
          save_configuration("facebook", configuration)
        end
    end
  end
end