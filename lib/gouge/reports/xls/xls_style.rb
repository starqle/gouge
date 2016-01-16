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
# @file_name lib/gouge/reports/xls/xls_style.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note This class contains style-definitions that mimic css class
# =============================================================================

class XlsStyle
  # Return styles for inputted classes
  # @param [Object] Classes to convert into styles
  #   String:                 'class_1'
  #   Space-seperated string: 'class_1 class_2'
  #   Symbol:                 :class_1
  #   Array:                  [:class_1, 'class_2 class_3']
  def self.get_class_style(classes = nil)
    classes ||= ''
    [classes].join(' ').split(' ')
      .collect(&:upcase)
      .select{ |upcase_class| self.const_defined? upcase_class }
      .inject({}){ |memo, upcase_class| memo.merge(self.const_get(upcase_class)) }
  end

private
  TABLE_HEADING = {
    weight: :bold
  }

  CENTER = {
    horizontal_align: :center
  }

  CURRENCY = {
    number_format: '$#,###.##'
  }
end
