#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Cummar
  module Providers
    class GooglePlus < Base
      def name
        "Google+"
      end

      def tag
        "google-plus"
      end

      def supported_fields
        ["social", "photo", "birthday"]
      end

      def has_authentication_data?
        configuration["token"].present?
      end

      def save_authentication(auth_data)
        configuration["token"] = auth_data["credentials"]["refresh_token"]
        save_configuration(configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            client = get_client
            plus = client.discovered_api("plus", "v1")

            @contacts = sort(fetch_contacts(client, plus).map {|person| build_contact(client, plus, person) }.compact)
            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(::Signet::AuthorizationError)
          raise e
        end
      end

      def profile_for(contact)
        contact.record["url"]
      end

      private
        def get_client
          client = Google::APIClient.new(application_name: "Cummar", application_version: "1.0.0")
          client.authorization = authorization
          client
        end

        def authorization
          authorization = Signet::OAuth2::Client.new(
            authorization_uri: "https://accounts.google.com/o/oauth2/auth",
            token_credential_uri: "https://accounts.google.com/o/oauth2/token",
            scope: "https://www.googleapis.com/auth/plus.login",
            client_id: configuration["app_key"],
            client_secret: configuration["app_secret"],
            redirect_uri: "http://localhost:7781/auth/google-plus/callback",
            refresh_token: configuration["token"]
          )

          authorization.fetch_access_token!
          authorization
        end

        def fetch_contacts(client, plus)
          rv = []
          token = ""

          while token do
            data = client.execute!(plus.people.list, {collection: "visible", userId: "me", maxResults: 100, orderBy: "alphabetical", pageToken: token}).data
            token = data["nextPageToken"]
            rv += data["items"]
          end

          rv
        end

        def build_contact(client, plus, user)
          id = user["id"]
          name = user["displayName"]
          picture = user["image"]["url"].gsub(/sz=50$/, "sz=128")
          profile = client.execute!(plus.people.get, {userId: id}).data
          birthday = parse_birthday(profile["birthday"])

          Cummar::RemoteContact.new(record: profile, provider: "google_plus", id: id, name: name, nick: id, photo: picture, birthday: birthday)
        end

        def parse_birthday(birthday)
          birthday ? Date.parse(birthday.gsub(/^0000/, Cummar::BIRTHDAY_NULL_YEAR.to_s), "%F") : nil
        end

        def clear_authentication
          configuration["token"] = ""
          save_configuration(configuration)
        end
    end
  end
end