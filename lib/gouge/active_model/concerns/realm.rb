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
# @file_name lib/gouge/active_model/concerns/realm.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::Realm concern
# =============================================================================

module Gouge
  module Realm
    extend ::ActiveSupport::Concern

    included do
      validates :app_id, presence: true
      belongs_to :app
      scope :app_scoped, -> { where(app_id: self.class.realm_app_class.current_app_id) }
    end

    module ClassMethods
      # NOP
    end
  end
end
