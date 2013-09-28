#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  module Providers
    class Twitter < Base
      def supported_fields
        ["social", "website", "photo"]
      end

      def has_authentication_data?
        configuration["token"].present? && configuration["token_secret"].present?
      end

      def save_authentication(auth_data)
        store_oauth(auth_data)
        save_configuration(configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            @contacts = sort(get_client.friends.map {|friend| build_contact(friend) })
            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(::Twitter::Error::Unauthorized) || e.is_a?(::Twitter::Error::BadRequest)
          raise e
        end
      end

      def profile_for(contact)
        "http://www.twitter.com/#{contact.nick}"
      end

      private
        def get_client
          ::Twitter::Client.new(
            consumer_key: configuration["app_key"], consumer_secret: configuration["app_secret"],
            oauth_token: configuration["token"], oauth_token_secret: configuration["token_secret"]
          )
        end

        def build_contact(user)
          Cummar::RemoteContact.new(
            record: user, provider: "twitter", id: user["id"], name: user["name"], nick: user["screen_name"],
            website: user["url"], photo: user["profile_image_url"]
          )
        end

        def clear_authentication
          configuration["token"] = ""
          configuration["token_secret"] = ""
          save_configuration(configuration)
        end
    end
  end
end