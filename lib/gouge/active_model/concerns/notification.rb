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
# @file_name lib/gouge/active_model/concerns/notification.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::Notification concern
# =============================================================================

module Gouge
  module Notification
    extend ::ActiveSupport::Concern

    included do
      after_initialize :initialize_notification
      attr_reader :notifications
    end

    def initialize_notification
      @notifications = {
        success: ::ActiveModel::Errors.new(self),
        warning: ::ActiveModel::Errors.new(self),
        info: ::ActiveModel::Errors.new(self)
      }
    end

    module ClassMethods
      # nop
    end
  end
end
