# =============================================================================
# Copyright (c) 2010-2016 All Right Reserved, http://starqle.com/
#
# This source is subject to the Starqle Permissive License.
# Please see the LICENSE.txt file for more information.
# All other rights reserved.
#
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
# KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE.
#
# @file_name lib/gouge/recurring_event/acts_as_recurring_event.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::RecurringEvent::ActsAsRecurringEvent module
# =============================================================================

module Gouge
  module RecurringEvent
    module ActsAsRecurringEvent
      extend ActiveSupport::Concern

      module ClassMethods
        def acts_as_recurring_event(options = {})
          include ::Gouge::RecurringEvent::Base
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, ::Gouge::RecurringEvent::ActsAsRecurringEvent
