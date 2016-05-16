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
# @file_name lib/gouge/record_locator.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::RecordLocator
# =============================================================================

module Gouge
  module RecordLocator
    ENCODER = Hash.new do |h,k|
      h[k] = Hash[ k.chars.map.enum_for(:each_with_index).to_a.map(&:reverse) ]
    end

    DECODER = Hash.new do |h,k|
      h[k] = Hash[ k.chars.map.enum_for(:each_with_index).to_a ]
    end

    # 0 through 9 plus A through Z, without B8S5O0I1 or Q.
    # "234679ACDEFGHJKLMNPRTUVWXYZ"
    BASE27 = (('0'..'9').to_a + ('A'..'Z').to_a).delete_if{|char| char =~ /[B8S5O0I1Q]/}.join

    class Base
      def self.encode(value)
        ring = RecordLocator::ENCODER[RecordLocator::BASE27]
        base = RecordLocator::BASE27.length
        result = []
        until value == 0
          result << ring[ value % base ]
          value /= base
        end
        result.reverse.join
      end

      def self.decode(string)
        string = string.to_s
        return string if string.split('').include?('1') || string.split('').include?('0') # as 0 and 1 are included into exceptional chars
        ring = RecordLocator::DECODER[RecordLocator::BASE27]
        base = RecordLocator::BASE27.length
        string.reverse.chars.enum_for(:each_with_index).inject(0) do |sum,(char,i)|
          sum + ring[char] * base**i
        end
      end
    end
  end
end
