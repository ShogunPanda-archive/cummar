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
        configuration["token"] = auth_data["credentials"]["token"]
        configuration["token_secret"] = auth_data["credentials"]["secret"]
        save_configuration("twitter", configuration)
      end

      def contacts
        begin
          @contacts = read_cache("twitter")

          if !@contacts then
            @contacts = sort(get_client.friends.map {|friend| build_contact(friend) })
            write_cache("twitter", @contacts)
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
          Cummar::RemoteContact.new(user, "twitter", user["id"], user["name"], user["screen_name"], user["url"], user["profile_image_url"])
        end

        def clear_authentication
          configuration["token"] = ""
          configuration["token_secret"] = ""
          save_configuration("twitter", configuration)
        end
    end
  end
end