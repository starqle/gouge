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
    TRUE_WHERE_QUERY = "1 = 1"
    FALSE_WHERE_QUERY = "1 = 2"

    #
    # Parse expression tree in polish notation
    #
    # Limitations and known issues
    # 1. Can only have one call to collection inside an expression, and it must be located just
    #    before terminal token
    # 2. Plural and singular inconsistency in expression
    #
    # Parsing Rule
    # 1. LHS MUST always be interpreted (thus it is mandatory for LHS to be an object)
    # 2. RHS can be subject (evaluated*) or value (as-is)
    #    If RHS is a subject:
    #       a. If operator is `IN` then convert RHS to subquery
    #       b. If operator is `=` then evaluate
    #
    def parse_expr_tree(expr_tree, opts = {})
      instruction = {
        selects: {},
        joins: [],
        where: ""
      }

      # If expr_tree is blank
      if expr_tree.blank?
        instruction[:where] = TRUE_WHERE_QUERY
        return instruction
      end

      # If expr_tree is not blank
      tree_operator = nil
      where_stack = []

      expr_tree.each_with_index do |expr, idx|
        if (idx == 0) && (%w(AND OR).include? expr)
          tree_operator = expr
        else
          if expr.is_a? Array
            result = parse_expr_tree(expr, opts)
            instruction[:joins] |= result[:joins].flatten
            instruction[:selects].merge! result[:selects]
            where = "(#{result[:where]})"
          else

            # =====================================================================================
            # TODO: @giosakti simplify this algorithm
            # =====================================================================================

            expr_stack = expr.scan(/(?:"(?:\\.|[^"])*"|[^" ])+/)
            if (expr_stack.size != 3) && (!%w(= IN).include? expr_stack[1])
              raise "Syntax error #{expr}"
            else
              operator = expr_stack[1]

              #
              # Evaluate lhs
              #
              lhs_expr = expr_stack.first
              if lhs_expr.start_with?("object")
                result = parse_lhs(lhs_expr, opts[:object], operator)
                lhs_join = result[:join]
                lhs_select = result[:select]
                lhs_where = result[:where]
              else
                raise "Syntax error: #{lhs_expr} at left-hand side"
              end

              #
              # Evaluate rhs
              #
              rhs_expr = expr_stack.last
              if rhs_expr.start_with?("subject")
                rhs_where = parse_rhs(rhs_expr, opts[:subject], operator)
              else
                rhs_where = rhs_expr
              end

              #
              # Formulaize instructions
              #
              instruction[:joins] |= [lhs_join] if lhs_join.present?
              instruction[:selects].merge! lhs_select if lhs_select.present?
              if rhs_where.present?
                where = "#{lhs_where} #{operator} #{rhs_where}"
              else
                where = FALSE_WHERE_QUERY
              end
            end

            # =====================================================================================
            # END TODO: @giosakti simplify this algorithm
            # =====================================================================================

          end

          where_stack.push where
        end
      end

      if tree_operator
        instruction[:where] = where_stack.join(" #{tree_operator} ")
      else
        instruction[:where] = where_stack.shift
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

              if query_tokens[0].start_with?("subject") || query_tokens[0].start_with?("object")
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
              else
                lhs_query = query_tokens[0].gsub(/\A'|'\Z/, '')
              end

              # Evaluate rhs
              rhs_query = ""

              if query_tokens[2].start_with?("subject") || query_tokens[2].start_with?("object")
                rhs_arr = query_tokens[2].split(".")

                # Identify root scope type
                case rhs_arr[0]
                when "subject"
                  rhs_scope = opts[:subject]
                when "object"
                  rhs_scope = opts[:object]
                else
                  raise "Syntax error #{token}"
                end

                # Iterate and evaluate every rhs_arr element
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

              # Formulaize instructions
              if rhs_query.present?
                if query_tokens[1] == "IN"
                  result = rhs_query.include? lhs_query
                # TODO: @bimo prevent inconsistent behaviour
                elsif lhs_query.is_a? Array
                  result = lhs_query.include? rhs_query
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

    private
      def parse_lhs(expr, object, operator)
        expr_tokens = expr.split(".")
        instruction = { select: nil, join: nil, where: "" }

        expr_tokens.to_enum.with_index.reverse_each do |token, idx|
          if idx == (expr_tokens.size - 1)
            instruction[:where] = token
            instruction[:select] = {"#{token}" => instruction[:where]}
          elsif idx > 0 && idx < (expr_tokens.size - 1)
            if instruction[:join].nil?
              instruction[:join] = token.to_sym
            else
              instruction[:join] = {token.to_sym => instruction[:join]}
            end
            instruction[:where] = "#{token.pluralize}.#{expr_tokens.last}"
            instruction[:select] = {"#{expr_tokens.last}" => instruction[:where]}
          else
            # If array size is 2, then we should rename scope to avoid ambiguity sql statement
            if expr_tokens.size == 2
              instruction[:where] = "#{object.table_name}.#{expr_tokens.last}"
              instruction[:select] = {"#{expr_tokens.last}" => instruction[:where]}
            end
          end
        end

        return instruction
      end

      def parse_rhs(expr, subject, operator)
        expr_tokens = expr.split(".")
        where = ""

        expr_tokens.each_with_index do |token, idx|
          if idx == 0
            # NOP
          elsif idx > 0 && idx < (expr_tokens.size - 1)
            subject = subject.send(token.to_sym)
          end

          if idx == (expr_tokens.size - 1)
            if operator == "IN"
              values = subject.map{|m| "'#{m.send(token.to_sym)}'"}
              where = "(#{values.join(',')})" if values.present?
            else
              where = "'#{subject.send(token.to_sym)}'"
            end
          end
        end

        return where
      end
  end
end
