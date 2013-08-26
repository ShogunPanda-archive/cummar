#!/usr/bin/env ruby
# encoding: utf-8
#
# Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  class LocalContact < Contact
    def self.load_addressbook(address_book)
      contacts = []
      address_book.people.each {|p| contacts << Cummar::LocalContact.new(p) }
      contacts.sort {|first, second| first.to_s <=> second.to_s }
    end

    def initialize(record)
      @record = record
    end

    def id
      @id ||= read_property(KABUIDProperty, false).gsub(":ABPerson", "")
    end

    def first_name
      @first_name ||= read_property(KABFirstNameProperty)
    end

    def last_name
      @last_name ||= read_property(KABLastNameProperty)
    end

    def nick
      @nick ||= read_property(KABNicknameProperty)
    end

    def company
      @company ||= read_property(KABOrganizationProperty)
    end

    def social
      @social ||= @record.valueForProperty(KABSocialProfileProperty, false)
    end

    def facebook
      social_username("Facebook")
    end

    def twitter
      social_username("Twitter")
    end

    def url
      if !@url then
        urls = read_property(KABURLsProperty, false)
        @url = ABMultiValueCopyValueAtIndex(urls, 0)
      end

      @url
    end

    def photo
      if !@photo then
        data = @record.imageData

        if data then
          @photo = "/tmp/cummar/image-#{id}.jpg"
          representation = NSImage.new.initWithData(data).representations.objectAtIndex(0)
          image_data = representation.representationUsingType(NSJPEGFileType, properties: nil)
          image_data.writeToFile(@photo, atomically: false)
        end
      end

      raise @photo.inspect if @photo.present?
    end

    def birthday
      @birthday ||= read_property(KABBirthdayProperty, false)
    end

    def is_company?
      @flags ||= read_property(KABPersonFlags, false)
      @flags & KABShowAsCompany > 0
    end

    def method_missing(method, *args, &block)
      if method =~ /^has_(.+)\?$/
        send($1).present?
      else
        super(method, *args, &block)
      end
    end

    def to_s(full = false)
      if !is_company? then
        rv = [first_name, (nick ? "\"#{nick}\"" : nil), last_name, (company ? "(#{company})" : nil)].compact.join(" ")

        if full then
          rv += "\n  Birthday: #{birthday.strftime("%d %B %Y")}" if has_birthday?
          rv += "\n  Photo: #{photo}" if has_photo?
          rv += "\n  " + [facebook ? "Facebok: #{facebook}" : nil, twitter ? "Twitter: #{twitter}" : nil].compact.join(", ") if has_social?
          rv += "\n  URL: #{url}" if has_url?
        end

        rv
      else
        "#{company} (Company)"
      end
    end
    
    private
      def read_property(key, strip = true)
        rv = @record.valueForProperty(key)
        rv = rv.try(:strip) if strip
        rv
      end

      def social_username(service)
        catch(:username) {
          social.count.times do |index|
            value = ABMultiValueCopyValueAtIndex(social, index)
            throw(:username, value["username"]) if value["serviceName"] == service
          end

          nil
        }    
      end
  end
end