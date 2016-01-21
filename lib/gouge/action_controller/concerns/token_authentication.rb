# =============================================================================
# Copyright (c) 2010-2016 All Right Reserved, http://starqle.com/
#
# This source is subject to the Starqle Permissive License.
# Please see the License.txt file for more information.
# All other rights reserved.
#
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
# KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE.
#
# @file_name lib/gouge/active_model/concerns/token_authentication.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::TokenAuthentication concern
# =============================================================================

module Gouge
  module TokenAuthentication
    extend ::ActiveSupport::Concern

    # Please see https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
    # before editing this file, the discussion is very interesting.

    included do
      private :authenticate_user_from_token!
      # This is our new function that comes before Devise's one
      before_action :authenticate_user_from_token!
      # This is Devise's authentication
      # before_action :authenticate_user!
      around_action :set_current_user
    end

    # For this example, we are simply using token authentication
    # via parameters. However, anyone could use Rails's token
    # authentication features to get the token from a header.
    def authenticate_user_from_token!
      # Set the authentication params if not already present
      if username = params[:username].blank? && request.headers["X-Username"]
        params[:username] = username
      end
      if authn_token = params[:authn_token].blank? && request.headers["X-User-Token"]
        params[:authn_token] = authn_token
      end

      username = params[:username].presence
      user = username && ::Fulcrum::User.find_by(username: username)

      # Notice how we use Devise.secure_compare to compare the token
      # in the database with the token given in the params, mitigating
      # timing attacks.
      if user &&
        ::Devise.secure_compare(user.authn_token, params[:authn_token]) &&
        DateTime.current < (user.current_sign_in_at + Devise.timeout_in)

        # Notice we are passing store false, so the user is not
        # actually stored in the session and a token is needed
        # for every request. If you want the token to work as a
        # sign in token, you can simply remove store: false.
        sign_in user, store: false

        # Set current user
        @current_user = user
      else
        # TODO: @giosakti investigate better behaviour for authentication during
        # testing
        raise LoginRequiredException unless ::Rails.env.test?
      end
    end

    def set_current_user
      begin
        ::Fulcrum::User.current_user_id = current_user.try(:id)
        yield
      ensure
        # Clean up var so that the thread may be recycled.
        # Note: Cleaning up on test environment will be handled by specs
        ::Fulcrum::User.current_user_id = nil unless Rails.env.test?
      end
    end

    module ClassMethods
      # nop
    end
  end
end
