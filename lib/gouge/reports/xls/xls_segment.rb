# =============================================================================
# Copyright (c) 2013 All Right Reserved, http://starqle.com/
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
# @file_name lib/reports/xls/xls_segment.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note This class writes xls_segments into xls file.
# =============================================================================

class XlsSegment
  # Position
  # --------------------

  # [Integer: nil] If not specified, their value depend on previous segment (if any) or 0
  attr_accessor :x, :y

  # [Symbol: :left]. Segment floating
  attr_accessor :floating

  # [Hash: {top: 0, right: 0, bottom: 0, left: 0}]
  attr_accessor :margin

  # Size
  # --------------------

  # [Integer: nil] Because they take colspan & rowspan into consideration, their value can only be calculated after this segment is printed
  attr_accessor :width, :height

  # [Integer: unlimited or 9999] Total max columns
  # attr_accessor :size

  # Content
  # --------------------

  # [Array (of array): []]
  attr_accessor :data

  # Misc
  # --------------------

  # [Boolean: true] If linked, It's position and dimension affect the next segment position
  attr_accessor :linked

  def initialize(opts = {})
    @floating = :left
    @margin = {top: 0, right: 0, bottom: 0, left: 0}
    @data = []
    @linked = true

    opts.each do |key, val|
      self.send "#{key}=", val if self.respond_to? "#{key}="
    end
  end

  def import_from_processed_grid(processed_grid, column_defs)
    @data = []

    # Parse parameter/option
    column_defs = JSON.parse(column_defs) if column_defs.instance_of? String
    column_defs = column_defs.collect(&:with_indifferent_access)

    # Print header
    @data << column_defs.map do |column_def|
      {
        value: column_def[:display_name] || column_def[:field].humanize,
        class: 'table_heading'
      }
    end

    # Print cells
    processed_grid.find_each do |entry|
      @data << column_defs.map do |column_def|
        {
          value: entry[column_def[:field].to_sym],
          style: column_def[:style],
          class: column_def[:class]
        }
      end
    end
  end
end
