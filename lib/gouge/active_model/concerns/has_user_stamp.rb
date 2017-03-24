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
# @file_name lib/gouge/active_model/concerns/has_user_stamp.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note HasUserStamp
# =============================================================================

class << ActiveRecord::Base
  def has_user_stamp(opts = {})
    include Gouge::UserStamp

    cattr_accessor :user_stamp_class
    self.user_stamp_class = (opts[:user_stamp_class] || ::Fulcrum::User)
  end
end
