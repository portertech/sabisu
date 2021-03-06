gem 'thin'
gem 'sinatra', '1.4.4'

# load gems
require 'sinatra'
require 'sinatra/base'
require 'sinatra/multi_route'
require 'couchrest'
require 'restclient'
require 'cgi'
require 'json'
require 'pp'

# load version number
require_relative 'version'

module Sabisu
  # run sabisu as a server
  class Server < Sinatra::Base
    register Sinatra::MultiRoute

    # load classes
    require_relative 'sensu'
    require_relative 'event'

    # load configuration settings
    require_relative 'config'

    # load routes
    require_relative 'routes/init'

    before '/:name' do
      unless params[:name] == 'login'
        session[:url] = request.fullpath
        force_session_auth
      end
    end

    before '/api/*' do
      protected!
    end

    get '/' do
      redirect '/login'
    end

    get '/login' do
      if logged_in?
        redirect '/events'
      else
        haml :login, locals: { remember_me: session[:remember_me] }
      end
    end

    post '/login' do
      if validate(params[:username], params['password'])
        session[:logged_in] = true
        session[:username] = params[:username]
        session[:remember_me] = params[:username] if params[:remember_me] == 'on'
        session[:url] = '/events' unless session.key?(:url)
        redirect session[:url]
      else
        haml :login, locals: { message: 'Incorrect username and/or password' }
      end
    end

    get '/logout' do
      clear_session
      redirect '/login'
    end

    helpers do
      def validate(username, password)
        username == UI_USERNAME && password == UI_PASSWORD
      end

      def logged_in?
        NOAUTH == true || (session[:logged_in] == true && session[:username])
      end

      def force_session_auth
        if logged_in?
          return true
        else
          redirect '/login'
          return false
        end
      end

      def clear_session
        session.clear
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? &&
          @auth.basic? &&
          @auth.credentials &&
          @auth.credentials == [UI_USERNAME, UI_PASSWORD]
      end

      def protected!
        unless authorized? || logged_in?
          response['WWW-Authenticate'] = "Basic realm='Sabisu requires authentication'"
          throw(:halt, [401, "Not authorized\n"])
        end
      end
    end
  end
end
