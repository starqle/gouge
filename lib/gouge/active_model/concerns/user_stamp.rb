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
# @file_name lib/gouge/active_model/concerns/user_stamp.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::UserStamp concern
# =============================================================================

module Gouge
  module UserStamp
    extend ::ActiveSupport::Concern

    included do
      belongs_to :created_by, class_name: "User"
      belongs_to :updated_by, class_name: "User"
      after_create :stamp_created_by
      after_save :stamp_updated_by
    end

    def stamp_created_by
      self.update_column(:created_by_id, ::Fulcrum::User.current_user_id)
    end

    def stamp_updated_by
      self.update_column(:updated_by_id, ::Fulcrum::User.current_user_id)
    end

    module ClassMethods
      # nop
    end
  end
end
