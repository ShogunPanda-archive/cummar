#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  class InvalidProvider < StandardError
  end

  module Providers
    class Base
      def tag
        self.class.to_s.demodulize.underscore
      end

      def name
        self.class.to_s.demodulize
      end

      def supported_fields
        ["social", "website", "photo", "birthday"]
      end

      def format_provider(field)
        case field
          when "linkedin" then "LinkedIn"
          when "google-plus", "google_plus" then "Google+"
          else field.capitalize
        end
      end

      def profile_for(field, user)
        user.social_profiles[format_provider(field)]
      end

      protected
        def configuration_path
          @configuration_path ||= Cummar::ROOT + "/config.yml"
        end

        def configuration_section
          @configuration_section ||= self.class.to_s.demodulize.underscore
        end

        def configuration
          @configuration ||= YAML.load_file(configuration_path).fetch(configuration_section)
        end

        def save_configuration(new_data)
          data = YAML.load_file(configuration_path)
          data[configuration_section] = (data[configuration_section] || {}).merge(new_data)
          open(configuration_path, "w") {|f| f.write(YAML.dump(data)) }
        end

        def read_cache
          data = Cummar::Server.cache[tag]
          valid_cache_data?(data) ? data[:data] : nil
        end

        def write_cache(value, ttl = 600)
          Cummar::Server.cache[tag] = {data: value, ttl: ttl.to_f, timestamp: Time.now.to_f}
        end

        def valid_cache_data?(data)
          data && Time.now.to_f < data[:timestamp] + data[:ttl]
        end

        def store_oauth(auth_data)
          configuration["token"] = auth_data["credentials"]["token"]
          configuration["token_secret"] = auth_data["credentials"]["secret"]
        end

        def sort(contacts)
          contacts.sort {|first, second|
            cmp = first.name.downcase <=> second.name.downcase
            cmp = first.nick.downcase <=> second.nick.downcase if cmp == 0
            cmp
          }
        end
    end
  end
end