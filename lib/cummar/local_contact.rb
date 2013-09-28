#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  class LocalContact
    attr_reader :id, :first_name, :last_name, :nick, :birthday, :company, :is_company
    attr_reader :facebook, :twitter, :linkedin, :google_plus, :instagram, :website, :photo, :social_profiles

    def self.load_addressbook(address_book, json = true)
      # Load and sort contacts
      contacts = []
      address_book.people.each {|record| contacts << Cummar::LocalContact.new(record) }
      contacts = Cummar::LocalContact.sort(contacts)

      # Now return as hash
      contacts.reduce({}) {|accumulator, contact|
        accumulator[contact.id] = json ? contact.as_json(no_ids: true) : contact
        accumulator
      }
    end

    def self.sort(contacts)
      contacts.sort {|first, second|
        cmp = (first.is_company ? 1 : 0) <=> (second.is_company ? 1 : 0)
        cmp = first.full_name.downcase <=> second.full_name.downcase if cmp == 0
        cmp
      }
    end

    def initialize(record)
      record.is_a?(Hash) ? initialize_from_hash(record) : initialize_from_record(record)
    end

    def method_missing(method, *args, &block)
      method =~ /^has_(.+)\?$/ ? send($1).present? : super(method, *args, &block)
    end

    def full_name(html = true)
      rv = if !is_company then
        [first_name, (nick ? "<em>\"#{nick}\"</em>" : nil), last_name, (company ? "(#{company})" : nil)].compact.join(" ")
      else
        "#{company} <em>(Company)</em>"
      end

      rv.gsub!(/<\/?em>/, "") if !html
      rv
    end

    def photo_url
      photo.gsub(Cummar::TMPDIR, "/images")
    end

    def format_birthday
      birthday.strftime(birthday.year == Cummar::BIRTHDAY_NULL_YEAR ? "%d %B" : "%d %B %Y")
    end

    def update_social(helper, value, provider)
      service, value, social = prepare_social_update(helper, provider, value)

      if social then
        social = social.mutableCopy
        perform_social_update(social, service, value)
      else
        social = ABMutableMultiValue.new
        social.addValue(value, withLabel: "None")
      end

      @record.setValue(social, forProperty: KABSocialProfileProperty)
    end

    def update_website(_, value, _)
      multivalue = ABMutableMultiValue.new
      multivalue.addValue(value, withLabel: KABHomePageLabel)
      @record.setValue(multivalue, forProperty: KABURLsProperty)
    end

    def update_photo(_, value, _)
      @record.setImageData(NSURL.URLWithString(value).resourceDataUsingCache(false))
    end

    def update_birthday(_, value, _)
      @record.setValue(value.to_time, forProperty: KABBirthdayProperty)
    end

    def as_json(options = {})
      vars = instance_variables
      vars.delete(:@social)
      vars.delete(:@record)
      vars.delete(:@id) if options[:no_ids]

      vars.reduce({}){ |rv, var|
        rv[var.to_s.gsub(/[:@]/, "").to_sym] = instance_variable_get(var)
        rv
      }
    end

    private
      def initialize_from_hash(record)
        @id = record[:id]
        @first_name = record[:first_name]
        @last_name = record[:last_name]
        @nick = record[:nick]
        @birthday = record[:birthday]
        @company = record[:company]
        @is_company = Cummar::Server.to_boolean(record[:is_company])
        @facebook = record[:facebook]
        @twitter = record[:twitter]
        @linkedin = record[:linkedin]
        @google_plus = record[:google_plus]
        @instagram = record[:instagram]
        @social_profiles = record[:social_profiles]
        @website = record[:website]
        @photo = record[:photo]
      end

      def initialize_from_record(record)
        @record = record
        @id = read_property(record, KABUIDProperty, false).gsub(":ABPerson", "")
        @first_name = read_property(record, KABFirstNameProperty)
        @last_name = read_property(record, KABLastNameProperty)
        @nick = read_property(record, KABNicknameProperty)
        @company = read_property(record, KABOrganizationProperty)
        @is_company = read_property(record, KABPersonFlags, false) & KABShowAsCompany > 0
        @website = website_from_record(record)
        @photo = photo_from_record(record)
        @birthday = read_property(record, KABBirthdayProperty, false)
        @birthday = @birthday.utc.to_date if @birthday
        initialize_social_profiles(record)
      end

      def initialize_social_profiles(record)
        @social = read_property(record, KABSocialProfileProperty, false)
        @facebook = social_username_for("Facebook")
        @twitter = social_username_for("Twitter")
        @linkedin = social_username_for("LinkedIn")
        @google_plus = social_username_for("Google+")
        @instagram = social_username_for("Instagram")
        @social_profiles = fetch_social_profiles
      end

      def read_property(record, key, strip = true)
        rv = record.valueForProperty(key)
        rv = rv.strip if rv && strip
        rv
      end

      def social_username_for(service)
        catch(:username) {
          (@social || []).count.times do |index|
            value = @social.valueAtIndex(index)
            throw(:username, value["username"]) if value["serviceName"] == service
          end

          nil
        }
      end

      def fetch_social_profiles
        (@social || []).count.times.reduce({}) { |accumulator, index|
          value = @social.valueAtIndex(index)
          accumulator[value["serviceName"]] = value["url"]
          accumulator
        }
      end

      def photo_from_record(record)
        data = record.imageData

        if data then
          FileUtils.mkdir_p(Cummar::TMPDIR)
          rv = Cummar::TMPDIR + "/image-#{id}.jpg"
          representation = NSImage.new.initWithData(data).representations.objectAtIndex(0)
          image_data = representation.representationUsingType(NSJPEGFileType, properties: nil)
          image_data.writeToFile(rv, atomically: false)

          rv
        else
          nil
        end
      end

      def website_from_record(record)
        ABMultiValueCopyValueAtIndex(read_property(record, KABURLsProperty, false), 0)
      end

      def profile_for(helper, provider, username)
        case provider
          when "facebook", "twitter", "instagram" then "http://www.#{provider}.com/#{username}"
          when "linkedin" then
            record = find_record(helper, username)
            record["record"]["public_profile_url"]
          when "google-plus" then
            record = find_record(helper, username)
            record["record"]["data"]["url"]
          else ""
        end
      end

      def prepare_social_update(helper, provider, value)
        service = case provider
          when "linkedin" then "LinkedIn"
          when "google-plus" then "Google+"
          else provider.capitalize
        end

        [
          service,
          {
            KABSocialProfileServiceKey => service,
            KABSocialProfileUsernameKey => value,
            KABSocialProfileURLKey => profile_for(helper, provider, value)
          },
          read_property(@record, KABSocialProfileProperty, false)
        ]
      end

      def perform_social_update(social, service, value)
        social.count.times do |index|
          current = @social.valueAtIndex(index)

          if current["serviceName"] == service then
            social.replaceValueAtIndex(index, withValue: value)
            return
          end
        end

        social.addValue(value, withLabel: "None")
      end

      def find_record(helper, id)
        catch(:record) do
          helper.records.each do |entry|
            throw(:record, entry) if entry["id"] == id
          end

          nil
        end
      end
  end
end