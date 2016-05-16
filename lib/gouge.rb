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
# @file_name lib/gouge.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge
# =============================================================================

require 'active_record'
require 'active_support/concern'

require 'gouge/action_controller/concerns/all'
require 'gouge/active_model/concerns/all'
require 'gouge/core_ext/boolean_typecast'
require 'gouge/exceptions/all'
require 'gouge/grid_processor'
require 'gouge/record_locator'
require 'gouge/recurring_event/all'
require 'gouge/report_generators/xls'
require 'gouge/shql'
require 'gouge/sortable_tree'

module Gouge
end
