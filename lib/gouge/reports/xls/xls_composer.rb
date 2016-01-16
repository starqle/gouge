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
# @file_name lib/gouge/reports/xls/xls_composer.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note This class writes xls_segments into xls file.
# =============================================================================

class XlsComposer
  attr_accessor :filepath
  attr_accessor :max_width
  attr_accessor :xls_segments

  def initialize(opts = {})
    @xls_segments = []
    opts.each do |key, val|
      self.send "#{key}=", val if self.respond_to? "#{key}="
    end
  end

  def self.generate(datasets, column_defs)
    xls_composer = XlsComposer.new
    xls_segment = XlsSegment.new
    xls_segment.import_from_processed_grid(datasets, column_defs)
    xls_composer.xls_segments.push xls_segment
    xls_composer.write
  end

  def write
    # Initialize book
    book = create_book
    sheet = book.create_worksheet

    # Write defined segments upon sheet
    write_segments_into_sheet sheet

    # Makes cells' width in the given worksheet fits its content
    autofit sheet

    # Write the book
    # write_book book

    string_io = StringIO.new
    book.write string_io
    string_io
  end

  private
    # Return generated default filepath
    def generate_default_filepath
      "#{SPREADSHEET_OUTPUT_PATH}/#{self.class.name.humanize}-#{Time.now.to_f.to_s.delete('.')}.xls"
    end

    # Return new book
    def create_book(opts = {})
      Spreadsheet::Workbook.new
    end

    # Save the given book into file
    def write_book(book)
      filepath ||= generate_default_filepath
      FileUtils.mkdir_p(File.dirname(filepath))
      book.write filepath
    end

    # Return new x after skip spanned-cells
    def consider_span(merged_cells, x, y)
      index = merged_cells.index{ |mc| [mc[0] <= y, y <= mc[1], mc[2] <= x, x <= mc[3]].all? }
      index.present? ? merged_cells[index][3] + 1 : x
    end

    # Return Spreadsheet::Format from hash
    def generate_format(classes, styles)
      Spreadsheet::Format.new XlsStyle.get_class_style(classes).merge([styles].flatten.compact.inject({}, :merge))
    end

    def write_segments_into_sheet(sheet)
      # initialize row index
      cury = 0

      # Ignore nil, then iterate through xls_segments
      xls_segments.compact.each do |segment|
        y = cury
        if segment.y
          y = segment.y
        else
          segment.y = y
        end

        # Initialize segment dimension
        segment.width = 0
        segment.height = 0

        y += segment.margin[:top]


        segment.data.each do |entry_row|
          row = sheet.row(y)

          # initialize row index
          x = segment.x || 0
          segment.x = x

          entry_row.each do |entry|
            if entry.instance_of? Hash
              x = consider_span(sheet.merged_cells, x, y)
              row[x] = entry[:value]
              row.set_format x, generate_format(entry[:class], entry[:style]) if entry[:class] || entry[:style]
              if entry[:colspan] || entry[:rowspan]
                # merge_cells start_row, start_col, end_row, end_col
                colspan = entry[:colspan] || 1
                rowspan = entry[:rowspan] || 1
                sheet.merge_cells(y, x, y + rowspan - 1, x += colspan - 1)
              end
            else
              row[x] = entry
            end
            x += 1
            segment.width = [segment.width, x-segment.x]
          end
          y += 1

          segment.height = [segment.height, y-segment.y]

        end

        if segment.linked
          cury = y + segment.margin[:bottom]
        end
      end
    end

    # Makes width of cells in the given worksheet fits its content
    # Based-on http://stackoverflow.com/questions/11621919/using-ruby-spreadsheet-gem-is-there-a-way-to-get-cell-to-adjust-to-size-of-cont
    def autofit(worksheet)
      (0...worksheet.column_count).each do |col|
        high = 1
        row = 0
        worksheet.column(col).each do |cell|
          w = cell==nil || cell=='' ? 1 : cell.to_s.strip.split('').count+3
          ratio = worksheet.row(row).format(col).font.size/10
          w = (w*ratio).round
          if w > high
            high = w
          end
          row=row+1
        end
        worksheet.column(col).width = high
      end
      (0...worksheet.row_count).each do |row|
        high = 1
        col = 0
        worksheet.row(row).each do |cell|
          w = worksheet.row(row).format(col).font.size+4
          if w > high
            high = w
          end
          col=col+1
        end
        worksheet.row(row).height = high
      end
    end
end
