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
# @file_name lib/gouge/reports/xls/xls_report.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note This class directly writes ngGrid relation into xls file.
# =============================================================================

module XlsReport
  require 'spreadsheet'
  extend ActiveSupport::Concern

  module ClassMethods
    def to_xls(options = {})
      # Parse options
      if options.instance_of? Hash
        column_defs = JSON.parse(options[:column_defs])
      else
        column_defs = JSON.parse(options)
      end
      column_defs = column_defs.collect(&:with_indifferent_access)

      # Initialize book
      book = Spreadsheet::Workbook.new
      sheet1 = book.create_worksheet
      sheet1.name = 'My First Worksheet'

      # Print header
      row_i = 0
      row = sheet1.row(row_i)
      column_defs.each do |column_def|
        row.push column_def[:display_name] || column_def[:field].humanize
      end

      # Print cell
      row_i += 1
      self.find_each do |entry|
        row = sheet1.row(row_i)
        column_defs.each do |column_def|
          row.push entry[column_def[:field].to_sym]
        end
        row_i += 1
      end

      # Write book
      write_book book
    end

    def write_book book
      file_path = "#{SPREADSHEET_OUTPUT_PATH}/#{self.class.name.humanize}-#{Time.now.to_f.to_s.delete('.')}.xls"
      FileUtils.mkdir_p(File.dirname(file_path))
      book.write file_path
    end
  end
end

class ActiveRecord::Base
  def self.acts_as_xls_report(options = {})
    include XlsReport
  end
end
