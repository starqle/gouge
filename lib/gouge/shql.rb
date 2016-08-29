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
# @file_name lib/gouge/shql.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Starqle Query Language
# =============================================================================

module Gouge
  module Shql
    TRUE_QUERY = "1 = 1"
    FALSE_QUERY = "1 = 2"

    def parse_json(opts = {})
      instruction = {}
      instruction[:joins] = []
      instruction[:selects] = {}

      # If json_arr is blank
      if opts[:json_arr].blank?
        instruction[:query] = TRUE_QUERY
        return instruction
      end

      # If json_arr is not blank
      operator = nil
      operand_stack = []
      opts[:json_arr].each_with_index do |token, idx|
        if (idx == 0) && (%w(AND OR).include? token)
          operator = token
        else
          if token.is_a? Array
            temp = parse_json(opts.merge({json_arr: token}))
            instruction[:joins] |= temp[:joins].flatten
            instruction[:selects].merge! temp[:selects]
            query = "(#{temp[:query]})"
          else

            # =====================================================================================
            # TODO: @giosakti simplify this algorithm
            # =====================================================================================

            query_tokens = token.scan(/(?:"(?:\\.|[^"])*"|[^" ])+/)
            if (query_tokens.size != 3) && (!%w(= IN).include? query_tokens[1])
              raise "Syntax error #{token}"
            else
              # Evaluate lhs
              lhs_join = nil
              lhs_select = nil
              lhs_query = ""
              lhs_arr = query_tokens[0].split(".")

              # Identify root scope type
              case lhs_arr[0]
              when "subject"
                lhs_scope = opts[:subject]
              when "object"
                lhs_scope = opts[:object]
              else
                raise "Syntax error #{token}"
              end

              lhs_arr.to_enum.with_index.reverse_each do |atom, idx|
                if idx == lhs_arr.size - 1
                  lhs_query = atom
                  lhs_select = {"#{atom}" => lhs_query}
                elsif idx < lhs_arr.size - 1 && idx > 0
                  if lhs_join.nil?
                    lhs_join = atom.to_sym
                  else
                    lhs_join = {atom.to_sym => lhs_join}
                  end
                  lhs_query = "#{atom}.#{lhs_arr[lhs_arr.size - 1]}"
                  lhs_select = {"#{lhs_arr[lhs_arr.size - 1]}" => lhs_query}
                else
                  # If array size is 2, then we should rename lhs_scope to avoid ambiguity sql statement
                  if lhs_arr.size == 2
                    lhs_query = "#{lhs_scope.table_name}.#{lhs_arr[lhs_arr.size - 1]}"
                    lhs_select = {"#{lhs_arr[lhs_arr.size - 1]}" => lhs_query}
                  end
                end
              end

              # Evaluate rhs
              rhs_query = ""

              if query_tokens[2].start_with?("subject") || query_tokens[2].start_with?("object")
                rhs_arr = query_tokens[2].split(".")

                # Identify root scope type
                case lhs_arr[0]
                when "subject"
                  rhs_scope = opts[:subject]
                when "object"
                  rhs_scope = opts[:object]
                else
                  raise "Syntax error #{token}"
                end

                rhs_arr.each_with_index do |atom, idx|
                  if idx == 0
                    # NOP
                  elsif idx > 0 && idx < (rhs_arr.size - 1)
                    rhs_scope = rhs_scope.send(atom.to_sym)
                  end

                  if idx == (rhs_arr.size - 1)
                    if query_tokens[1] == "IN"
                      values = rhs_scope.map{|m| "'#{m.send(atom.to_sym)}'"}
                      rhs_query = "(#{values.join(',')})" if values.present?
                    else
                      rhs_query = "'#{rhs_scope.send(atom.to_sym)}'"
                    end
                  end
                end
              else
                rhs_query = query_tokens[2]
              end

              instruction[:joins] |= [lhs_join] if lhs_join.present?
              instruction[:selects].merge! lhs_select if lhs_select.present?
              if rhs_query.present?
                query = "#{lhs_query} #{query_tokens[1]} #{rhs_query}"
              else
                query = FALSE_QUERY
              end
            end

            # =====================================================================================
            # END TODO: @giosakti simplify this algorithm
            # =====================================================================================

          end
          operand_stack.push query
        end
      end

      if operator
        instruction[:query] = operand_stack.join(" #{operator} ")
      else
        instruction[:query] = operand_stack.shift
      end

      return instruction
    end

    def evaluate_json(opts = {})
      # If json_arr is blank
      return true if opts[:json_arr].blank?

      # If json_arr is not blank
      operator = nil
      operand_stack = []
      opts[:json_arr].each_with_index do |token, idx|
        if (idx == 0) && (%w(AND OR).include? token)
          operator = token
        else
          if token.is_a? Array
            result = evaluate_json(opts.merge({json_arr: token}))
          else

            # =====================================================================================
            # TODO: @giosakti simplify this algorithm
            # =====================================================================================

            query_tokens = token.scan(/(?:"(?:\\.|[^"])*"|[^" ])+/)
            if (query_tokens.size != 3) && (!%w(= IN).include? query_tokens[1])
              raise "Syntax error #{token}"
            else
              # Evaluate lhs
              lhs_query = ""
              lhs_arr = query_tokens[0].split(".")

              # Identify root scope type
              case lhs_arr[0]
              when "subject"
                lhs_scope = opts[:subject]
              when "object"
                lhs_scope = opts[:object]
              else
                raise "Syntax error #{token}"
              end

              # Iterate and evaluate every lhs_arr element
              lhs_arr.each_with_index do |atom, idx|
                if idx == 0
                  # NOP
                elsif idx > 0 && idx < lhs_arr.size
                  if lhs_scope.is_a? ActiveRecord::Associations::CollectionProxy
                    lhs_scope = lhs_scope.map{ |m| m.send(atom.to_sym) }
                  else
                    lhs_scope = lhs_scope.send(atom.to_sym)
                  end
                end

                lhs_query = lhs_scope
              end

              # Evaluate rhs
              rhs_query = ""

              if query_tokens[2].start_with?("subject") || query_tokens[2].start_with?("object")
                rhs_arr = query_tokens[2].split(".")

                # Identify root scope type
                case lhs_arr[0]
                when "subject"
                  rhs_scope = opts[:subject]
                when "object"
                  rhs_scope = opts[:object]
                else
                  raise "Syntax error #{token}"
                end

                rhs_arr.each_with_index do |atom, idx|
                  if idx == 0
                    # NOP
                  elsif idx > 0 && idx < rhs_arr.size
                    if rhs_scope.is_a? ActiveRecord::Associations::CollectionProxy
                      rhs_scope = rhs_scope.map{ |m| m.send(atom.to_sym) }
                    else
                      rhs_scope = rhs_scope.send(atom.to_sym)
                    end
                  end

                  rhs_query = rhs_scope
                end
              else
                rhs_query = query_tokens[2].gsub(/\A'|'\Z/, '')
              end

              if rhs_query.present?
                if query_tokens[1] == "IN"
                  result = rhs_query.include? lhs_query
                else
                  result = (lhs_query == rhs_query)
                end
              else
                result = false
              end
            end

            # =====================================================================================
            # END TODO: @giosakti simplify this algorithm
            # =====================================================================================

          end
          operand_stack.push result
        end
      end

      if operator
        if operator == "AND"
          result = operand_stack.all?
        else
          result = operand_stack.any?
        end
      else
        result = operand_stack.shift
      end

      return result
    end
  end
end
