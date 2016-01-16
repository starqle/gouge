# =============================================================================
# Copyright (c) 2015 All Right Reserved, http://starqle.com/
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
# @file_name lib/gouge/active_model/concerns/token_authenticable.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::TokenAuthenticable concern
# =============================================================================

module Gouge
  module TokenAuthenticable
    extend ::ActiveSupport::Concern

    # Please see https://gist.github.com/josevalim/fb706b1e933ef01e4fb6
    # before editing this file, the discussion is very interesting.

    included do
      private :generate_authentication_token

      # TODO: @giosakti what's this callback for?
      before_save :ensure_authentication_token!
    end

    def ensure_authentication_token!
      if authn_token.blank?
        self.authn_token = generate_authentication_token
      end
    end

    def generate_authentication_token
      loop do
        token = ::Devise.friendly_token
        break token unless self.class.where(authn_token: token).first
      end
    end

    module ClassMethods
      # nop
    end
  end
end
