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
# @file_name lib/gouge/active_model/concerns/has_token_authentication.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note HasTokenAuthentication
# =============================================================================

class << ActionController::Base
  def has_token_authentication(opts = {})
    include Gouge::TokenAuthentication

    cattr_accessor :token_authentication_class
    self.token_authentication_class = (opts[:token_authentication_class] || ::Fulcrum::User)
  end
end
