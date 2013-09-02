#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  module Providers
    class Linkedin < Base
      def name
        "LinkedIn"
      end

      def has_authentication_data?
        configuration["token"].present? && configuration["token_secret"].present?
      end

      def save_authentication(auth_data)
        configuration["token"] = auth_data["credentials"]["token"]
        configuration["token_secret"] = auth_data["credentials"]["secret"]
        save_configuration("linkedin", configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            client = get_client
            contacts = []
            start = 0
            count = 100

            while start do
              connections = client.connections(fields: ["id", "formatted-name", "picture-url", "public-profile-url"], start: start, count: count)["all"]

              if connections then
                contacts += connections
                start += count
              else
                start = nil
              end
            end

            @contacts = sort(contacts.map {|connection| build_contact(connection) }.compact)
            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(::LinkedIn::Errors::UnauthorizedError)
          raise e
        end
      end

      def profile_for(contact)
        contact.record["public_profile_url"]
      end

      def supported_fields
        ["social", "photo"]
      end

      private
        def get_client
          client = ::LinkedIn::Client.new(configuration["app_key"], configuration["app_secret"])
          client.authorize_from_access(configuration["token"], configuration["token_secret"])
          client
        end

        def build_contact(user)
          nick = if user["public_profile_url"] then
            user["public_profile_url"].gsub(/#{Regexp.quote("http://www.linkedin.com/")}[^\/]+\/([^\/]+)(\/.+)?/, "\\1")
          else
            user["id"]
          end

          user["id"] != "private" ? Cummar::RemoteContact.new(user, "linkedin", user["id"], user["formatted_name"], nick, nil, user["picture_url"]) : nil
        end

        def clear_authentication
          configuration["token"] = ""
          configuration["token_secret"] = ""
          save_configuration("linkedin", configuration)
        end
    end
  end
end