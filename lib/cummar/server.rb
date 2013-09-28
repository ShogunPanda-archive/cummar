#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Cummar
  ROOT = File.dirname(__FILE__) + "/../../"
  CONFIGURATION = YAML.load_file(ROOT + "/config.yml")
  TMPDIR = "/tmp/cummar"
  BIRTHDAY_NULL_YEAR = 1604

  class Server < Sinatra::Base
    def self.uri
      @uri ||= "http://localhost:#{Cummar::Server.port}"
    end

    def self.load_provider(provider, instantiate = true)
      begin
        klass = "::Cummar::Providers::#{provider.gsub("-", "_").camelize}".constantize
        instantiate ? klass.new : klass
      rescue NameError
        raise Cummar::InvalidProvider.new
      end
    end

    def self.cache
      @cache ||= Moneta.new(:Memory)
    end

    def self.to_boolean(obj)
      obj.to_s =~ /^(\s*(1|true|yes|t|y)\s*)$/i
    end

    configure do
      use(OmniAuth::Builder) do
        provider(:facebook, CONFIGURATION["facebook"]["app_key"], CONFIGURATION["facebook"]["app_secret"])
        provider(:twitter, CONFIGURATION["twitter"]["app_key"], CONFIGURATION["twitter"]["app_secret"])
        provider(:linkedin, CONFIGURATION["linkedin"]["app_key"], CONFIGURATION["linkedin"]["app_secret"], scope: "r_fullprofile r_emailaddress r_network")
        provider(
          :google_oauth2, CONFIGURATION["google_plus"]["app_key"], CONFIGURATION["google_plus"]["app_secret"],
          name: "google-plus", scope: "plus.login", access_type: "offline", prompt: "consent"
        )
        provider(:instagram, CONFIGURATION["instagram"]["app_key"], CONFIGURATION["instagram"]["app_secret"])

        OmniAuth.config.on_failure = Proc.new { |env|
          OmniAuth::FailureEndpoint.new(env).redirect_to_failure
        }
      end

      Compass.configuration do |config|
        config.output_style = :compact
        config.line_comments = false
      end

      Slim::Engine.set_default_options({
        shortcut: { "@" => {attr: "data-role"}, "#" => {attr: "id"}, "." => {attr: "class"}}, pretty: true, sort_attrs: true, tabsize: 2}
      )

      set(:sessions, true)
      set(:port, 7781)
      set(:views, ROOT + "views")
      set(:public_dir, ROOT + "views")
      set(:show_exceptions, false)
      set(:dump_errors, false)
      set(:scss, Compass.sass_engine_options)
    end

    not_found do
      @code = 404
      @title = "Request Not Found"
      @message = "The request your asked for was not found."

      status(@code)
      slim(:error, layout: :layout)
    end

    error(403) do
      @code = 403
      @title = "Authorization denied"

      status(@code)
      slim(:error, layout: :layout)
    end

    error(406) do
      @code = 406
      @title = "Invalid social network"
      @message = "The social network you asked for is invalid."

      status(@code)
      slim(:error, layout: :layout)
    end

    error do
      @exception = env["sinatra.error"]
      @code = 500

      if @exception.is_a?(RuntimeError) then
        @code = 200

        if Cummar::Server.to_boolean(params[:raw]) then
          content_type("text/javascript", charset: "utf-8")
          status(@code)
          @exception.message
        else
          status(@code)
          slim(:debug, layout: :layout)
        end
      else
        @title = @exception_title || "Error occurred"
        @message = "[#{@exception.class.to_s}] #{@exception.message}"

        status(@code)
        slim(:error, layout: :layout)
      end
    end

    get "/style.css" do
      content_type("text/css", charset: "utf-8")
      scss(:style)
    end

    get "/list.js" do
      content_type("text/javascript", charset: "utf-8")
      coffee(:list)
    end

    get /^\/images\/(?<image>image-[0-9A-F-]+\.jpg)$/ do
      path = Cummar::TMPDIR + "/#{params[:image]}"

      if File.exists?(path) then
        send_file(path, type: :jpg)
      else
        halt(404)
      end
    end

    get "/" do
      slim(:index, layout: :layout)
    end

    get "/auth/:provider/callback" do
      begin
        Cummar::Server.load_provider(params[:provider]).save_authentication(env["omniauth.auth"])
        redirect "/list/#{params[:provider]}"
      rescue Cummar::InvalidProvider
        halt(404)
      end
    end

    get "/auth/failure" do
      @message = params[:message]
      halt(403)
    end

    get "/list/:provider" do
      begin
        @provider = Cummar::Server.load_provider(params[:provider])

        if @provider.has_authentication_data? then
          @local_contacts = Cummar::Server.load_provider("local").contacts
          @remote_contacts = @provider.contacts
          slim(:list, layout: :layout)
        else
          redirect("/auth/#{params[:provider]}")
        end
      rescue Cummar::InvalidProvider
        halt(404)
      end
    end

    ["get", "post"].each do |verb|
      send(verb, "/update/:provider") do
        begin
          Cummar::Server.load_provider(params[:provider], false) # This is only for check that the specified provider exists.
          @updates = Cummar::Server.load_provider("local").update(params[:provider], params[:updates])
          slim(:update, layout: :layout)
        rescue Cummar::InvalidProvider
          halt(404)
        end
      end
    end
  end
end