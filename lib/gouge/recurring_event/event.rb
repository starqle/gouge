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
# @file_name lib/gouge/recurring_event/event.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::RecurringEvent::Event
# =============================================================================

module Gouge
  module RecurringEvent
    class Event
      attr_accessor :ref_obj,
        :from_time_in_secs,
        :thru_time_in_secs

      def initialize(ref_obj, from_time, thru_time)
        @ref_obj = ref_obj
        @from_time_in_secs = self.convert_to_secs(from_time)
        @thru_time_in_secs = self.convert_to_secs(thru_time)
      end

      def self.convert_to_secs(time)
        case time.class
        when DateTime
          time.strftime('%s')
        when Time
          time.strftime('%s')
        when Integer
          time
        when NilClass
          nil
        else
          raise "Cannot convert to secs, unknown object class!"
        end
      end

      def self.convert_to_datetime(time)
        case time.class
        when DateTime
          time
        when Time
          time.to_datetime
        when Integer
          DateTime.strptime("#{time}", '%s')
        when NilClass
          nil
        else
          raise "Cannot convert to datetime, unknown object class!"
        end
      end
    end
  end
end
