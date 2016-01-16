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
# @file_name lib/shql/shql.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Starqle Query Language
# =============================================================================

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

          # =======================================================================================
          # TODO: @giosakti simplify this algorithm
          # =======================================================================================

          query_tokens = token.scan(/(?:"(?:\\.|[^"])*"|[^" ])+/)
          if (query_tokens.size != 3) && (!%w(= IN).include? query_tokens[1])
            raise "Syntax error #{token}"
          else
            lhs_join = nil
            lhs_select = nil
            lhs_query = ""
            lhs_arr = query_tokens[0].split(".")
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
                # If array size is 2, then we should rename object to avoid ambiguity sql statement
                if lhs_arr.size == 2
                  lhs_query = "#{opts[:object].table_name}.#{lhs_arr[lhs_arr.size - 1]}"
                  lhs_select = {"#{lhs_arr[lhs_arr.size - 1]}" => lhs_query}
                end
              end
            end

            rhs_query = ""
            if query_tokens[2].start_with? "subject"
              subject_scope = opts[:subject]
              rhs_arr = query_tokens[2].split(".")
              rhs_arr.each_with_index do |atom, idx|
                # If subject is not exist then there is no need to construct query, move along
                unless subject_scope
                  rhs_query = ""
                  next
                end

                if idx == 0
                  # NOP
                elsif idx > 0 && idx < (rhs_arr.size - 1)
                  subject_scope = subject_scope.send(atom.to_sym)
                end

                if idx == (rhs_arr.size - 1)
                  if query_tokens[1] == "IN"
                    values = subject_scope.map{|m| "'#{m.send(atom.to_sym)}'"}
                    rhs_query = "(#{values.join(',')})" if values.present?
                  else
                    rhs_query = "'#{subject_scope.send(atom.to_sym)}'"
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

          # =======================================================================================
          # END TODO: @giosakti simplify this algorithm
          # =======================================================================================

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

          # =======================================================================================
          # TODO: @giosakti simplify this algorithm
          # =======================================================================================

          query_tokens = token.scan(/(?:"(?:\\.|[^"])*"|[^" ])+/)
          if (query_tokens.size != 3) && (!%w(= IN).include? query_tokens[1])
            raise "Syntax error #{token}"
          else
            lhs_query = ""
            object_scope = opts[:object]
            lhs_arr = query_tokens[0].split(".")
            lhs_arr.each_with_index do |atom, idx|
              if idx == 0
                # NOP
              elsif idx > 0 && idx < lhs_arr.size
                if object_scope.is_a? ActiveRecord::Associations::CollectionProxy
                  object_scope = object_scope.map{ |m| m.send(atom.to_sym) }
                else
                  object_scope = object_scope.send(atom.to_sym)
                end
              end

              lhs_query = object_scope
            end

            rhs_query = ""
            if query_tokens[2].start_with? "subject"
              subject_scope = opts[:subject]
              rhs_arr = query_tokens[2].split(".")
              rhs_arr.each_with_index do |atom, idx|
                if idx == 0
                  # NOP
                elsif idx > 0 && idx < rhs_arr.size
                  if subject_scope.is_a? ActiveRecord::Associations::CollectionProxy
                    subject_scope = subject_scope.map{ |m| m.send(atom.to_sym) }
                  else
                    subject_scope = subject_scope.send(atom.to_sym)
                  end
                end

                rhs_query = subject_scope
              end
            else
              rhs_query = query_tokens[2].gsub(/\A'|'\Z/, '')
            end

            if rhs_query.present?
              if lhs_query.is_a? Array
                result = lhs_query.include? rhs_query
              else
                if query_tokens[1] == "="
                  result = (lhs_query == rhs_query)
                else
                  result = rhs_query.include? lhs_query
                end
              end
            else
              result = false
            end
          end

          # =======================================================================================
          # END TODO: @giosakti simplify this algorithm
          # =======================================================================================

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
