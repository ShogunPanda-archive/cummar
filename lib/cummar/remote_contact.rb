#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  class RemoteContact
    attr_reader :id, :provider, :name, :nick, :birthday, :website, :photo, :record

    def initialize(attrs = {})
      @record = attrs[:record]
      @provider = attrs[:provider]
      @id = attrs[:id]
      @name = attrs[:name] || ""
      @nick = attrs[:nick] || ""
      @birthday = attrs[:birthday]
      @website = attrs[:website]
      @photo = attrs[:photo]
    end

    def method_missing(method, *args, &block)
      method =~ /^has_(.+)\?$/ ? send($1).present? : super(method, *args, &block)
    end

    def format_birthday
      birthday.strftime(birthday.year == Cummar::BIRTHDAY_NULL_YEAR ? "%d %B" : "%d %B %Y")
    end

    def as_json
      {
        id: id,
        provider: provider,
        name: name,
        social: nick,
        birthday: (has_birthday? ? birthday.strftime("%F") : nil),
        website: website,
        photo: photo
      }.reject{|_, v| v.blank?}
    end
  end
end
