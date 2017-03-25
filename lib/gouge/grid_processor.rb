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
# @file_name lib/gouge/grid_processor.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note GridProcessor for API
# =============================================================================

module Gouge
  module GridProcessor
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 10
    DEFAULT_SORT_INFO = {fields: ["created_at"], directions: ["DESC"]}
    VALID_PER_PAGES = [10, 20, 25, 50, 100, 200]
    DEFAULT_ENABLE_PAGING = true

    # Return processed active record relation based on input parameters
    #
    # @param klass [Class, ActiveRecord::Relation] Class or active record relation as a starting point
    # @param column_defs [String, Hash] columns to be displayed (from grid)
    # @param q [String] user-submitted query (from grid)
    # @param filter_params [String] query in json format that define advanced search operation (from grid)
    # @param page [String] page to be displayed (from grid)
    # @param per_page [String] entries per page to be displayed (from grid)
    # @param sort_info [String] sorting rules to be used (from grid)
    # @param join_objects [Object, Array] objects to be joined
    # @param field_lookup [Hash] lookup table for fields that needs to be converted into sql-friendly names
    # @param custom_where_query [String] custom where query
    # @param group_by_query [String] group by query
    # @return [ActiveRecord::Relation] Processed active record relation
    def process_grid(opts = {})
      klass = opts[:klass] || nil
      column_defs = opts[:column_defs] || nil
      q = opts[:q] || nil
      filter_params = opts[:filter_params] || nil
      page = opts[:page] || DEFAULT_PAGE
      per_page = opts[:per_page] || DEFAULT_PER_PAGE
      sort_info = opts[:sort_info] || DEFAULT_SORT_INFO
      enable_paging = opts[:enable_paging] || DEFAULT_ENABLE_PAGING
      join_objects = opts[:join_objects] || []
      field_lookup = opts[:field_lookup] || {}
      custom_where_query = opts[:custom_where_query] || nil
      group_by_query = opts[:group_by_query] || nil

      # Enforce default values
      page ||= DEFAULT_PAGE
      per_page ||= DEFAULT_PER_PAGE
      sort_info ||= DEFAULT_SORT_INFO
      enable_paging = %w[FALSE False false 0 NO No no].include?(enable_paging) ? false : DEFAULT_ENABLE_PAGING

      # Parse parameters into correct format
      column_defs = parse_params(column_defs)
      filter_params = parse_params(filter_params)
      page = page.to_i
      per_page = per_page.to_i
      sort_info = parse_params(sort_info)
      field_lookup = parse_params(field_lookup)

      # Check for client errors
      raise "Invalid per_page parameter. Valid values are #{VALID_PER_PAGES}" unless VALID_PER_PAGES.include?(per_page)
      sort_info ||= {}

      # select
      select_query = process_select(klass, column_defs, field_lookup)
      objects = klass.select(select_query)

      # join (optional)
      objects = [join_objects].flatten.compact.inject(objects, :joins) unless [join_objects].flatten.compact.empty?

      # where
      objects = objects.where(custom_where_query) if custom_where_query
      if filter_params
        where_query = process_advanced_search_query_where(column_defs, filter_params, field_lookup)
      else
        where_query = process_where(column_defs, q, field_lookup)
      end
      objects = objects.where(where_query)

      # group
      if group_by_query
        objects = objects.group(group_by_query)

        # Convert objects from group_by_query to array
        # so its size can be grokked
        objects.to_a
      end

      # Force per_page value with total_entries and page value with 1.
      # Happens when pagination is disabled.
      unless enable_paging
        per_page = objects.size
        page = 1
      end

      # pagination
      # TODO: @ralibi this is fix for total entries when using group by query and
      # pagination
      objects = objects.paginate(page: page, per_page: per_page, total_entries: objects.size)

      # order
      order_query = process_order(sort_info, field_lookup)
      objects = objects.reorder(order_query) unless objects.empty?

      objects
    end

    # Return processed active record relation based on input parameters
    # This method utilize query-in-query to accomodate more complex requirements.
    #
    # @param klass [Class, ActiveRecord::Relation] Class or active record relation as a starting point
    # @param column_defs [String, Hash] columns to be displayed (from grid)
    # @param q [String] user-submitted query (from grid)
    # @param page [String] page to be displayed (from grid)
    # @param per_page [String] entries per page to be displayed (from grid)
    # @param sort_info [String] sorting rules to be used (from grid)
    # @param field_lookup [Hash] lookup table for fields that needs to be converted into sql-friendly names
    # @param inner_join_query [String] custom inner join query
    # @param inner_where_query [String] custom inner where query
    # @param inner_group_query [String] custom inner group query
    # @return [ActiveRecord::Relation] Processed active record relation
    def process_subquery_grid(opts = {})
      klass = opts[:klass] || nil
      column_defs = opts[:column_defs] || nil
      q = opts[:q] || nil
      page = opts[:page] || DEFAULT_PAGE
      per_page = opts[:per_page] || DEFAULT_PER_PAGE
      sort_info = opts[:sort_info] || DEFAULT_SORT_INFO
      field_lookup = opts[:field_lookup] || {}
      inner_join_query = opts[:inner_join_query] || nil
      inner_where_query = opts[:inner_where_query] || nil
      inner_group_query = opts[:inner_group_query] || nil

      # Enforce default values
      page ||= DEFAULT_PAGE
      per_page ||= DEFAULT_PER_PAGE
      sort_info ||= DEFAULT_SORT_INFO

      # Parse parameters into correct format
      column_defs = parse_params(column_defs)
      page = page.to_i
      per_page = per_page.to_i
      sort_info = parse_params(sort_info)

      # Check for client errors
      raise "Invalid per_page parameter. Valid values are #{VALID_PER_PAGES}" unless (VALID_PER_PAGES).include? per_page
      sort_info ||= {}

      # inner query
      inner_select_query = process_select(klass, column_defs, field_lookup)
      inner_select_query += ", #{klass.table_name}.#{inner_group_query} AS #{inner_group_query}" unless inner_group_query.blank?
      inner_query = %{
        SELECT
          #{inner_select_query}
        FROM
          #{klass.table_name}
      }
      inner_query += " #{inner_join_query}" unless inner_join_query.blank?
      inner_query += " WHERE #{inner_where_query}" unless inner_where_query.blank?
      inner_query += " GROUP BY #{inner_group_query}" unless inner_group_query.blank?

      # outer query
      outer_query = %{
        SELECT *
        FROM
          (#{inner_query}) AS internal
      }

      # filter & order
      filtered_query = outer_query
      where_query = process_where(column_defs, q, field_lookup, true)
      filtered_query += " WHERE #{where_query}" unless where_query.blank?
      order_query = process_order(sort_info, field_lookup)
      filtered_query += " ORDER BY #{order_query}" unless order_query.blank?

      # pagination
      objects = klass.paginate_by_sql(filtered_query, page: page, per_page: per_page)

      objects
    end

    private

      def field_to_fqn(field, field_lookup)
        field_lookup[field].nil? ? field : field_lookup[field]
      end

      def process_select(klass, column_defs, field_lookup)
        # if it's nil then set empty value of field_lookup
        field_lookup ||= {}

        array = []
        column_defs.each do |column_def|
          array.push "#{field_to_fqn(column_def['field'], field_lookup)} AS #{column_def['field']}"
        end

        # FIELD_LOOKUP variable can also used to add additional field necessary
        # for the API.
        (field_lookup.keys - column_defs.collect{|c| c['field']}).each do |k|
          array.push "#{field_lookup[k]} AS #{k}"
        end

        # explicitly select column id if it hasn't been selected already
        #
        # Note: @giosakti This code check whether array is empty or not due to
        # weird behavior of will_paginate gem. If it's empty then we can't
        # use sql column alias.
        if array.empty?
          array.push "#{klass.table_name}.id"
        end

        array.join(", ")
      end

      def process_where(column_defs, q, field_lookup, use_alias = false)
        array = []
        column_defs.each do |column_def|
          if column_def['traversed_by_q'] == true
            if use_alias
              array.push "lower(#{column_def['field']}) LIKE lower('%#{q}%')"
            else
              array.push "lower(#{field_to_fqn(column_def['field'], field_lookup)}) LIKE lower('%#{q}%')"
            end
          end
        end

        array.join(" OR ")
      end

      def process_advanced_search_query_where(column_defs, filter_params, field_lookup)
        array = []

        # Convert column_defs to array of fields
        column_def_fields = column_defs.map{|m| m['field']} | field_lookup.keys.collect(&:to_s)

        unless filter_params.nil?
          # Process each key-value in filter_params
          filter_params.each do |k, v|

            # Take the last word in key that is separated by underscore and
            # put it into 'expr' variable
            field = k.split('_')
            expr = field.pop
            field = field.join('_')

            # Only process if column_def_fields contains field and value is present
            if column_def_fields.include?(field) && v.present?

              # Process based on 'expr' variable
              case expr
              when 'cont'
                array.push "lower(#{field_to_fqn(field, field_lookup)}) LIKE lower('%#{v}%')"
              when 'match'
                array.push "lower(#{field_to_fqn(field, field_lookup)}) LIKE lower('#{v}')"

              when 'eq'
                array.push "#{field_to_fqn(field, field_lookup)} = #{v}"
              when 'lt'
                array.push "#{field_to_fqn(field, field_lookup)} < #{v}"
              when 'lteq'
                array.push "#{field_to_fqn(field, field_lookup)} <= #{v}"
              when 'gt'
                array.push "#{field_to_fqn(field, field_lookup)} > #{v}"
              when 'gteq'
                array.push "#{field_to_fqn(field, field_lookup)} >= #{v}"

              when 'eqdate'
                array.push "DATE(#{field_to_fqn(field, field_lookup)}) = '#{DateTime.parse(v).in_time_zone.to_date}'"
              when 'ltdate'
                array.push "DATE(#{field_to_fqn(field, field_lookup)}) < '#{DateTime.parse(v).in_time_zone.to_date}'"
              when 'lteqdate'
                array.push "DATE(#{field_to_fqn(field, field_lookup)}) <= '#{DateTime.parse(v).in_time_zone.to_date}'"
              when 'gtdate'
                array.push "DATE(#{field_to_fqn(field, field_lookup)}) > '#{DateTime.parse(v).in_time_zone.to_date}'"
              when 'gteqdate'
                array.push "DATE(#{field_to_fqn(field, field_lookup)}) >= '#{DateTime.parse(v).in_time_zone.to_date}'"

              when 'eqdatetime'
                array.push "(EXTRACT(EPOCH FROM #{field_to_fqn(field, field_lookup)}) * 1000) = #{v}"
              when 'ltdatetime'
                array.push "(EXTRACT(EPOCH FROM #{field_to_fqn(field, field_lookup)}) * 1000) < #{v}"
              when 'lteqdatetime'
                array.push "(EXTRACT(EPOCH FROM #{field_to_fqn(field, field_lookup)}) * 1000) <= #{v}"
              when 'gtdatetime'
                array.push "(EXTRACT(EPOCH FROM #{field_to_fqn(field, field_lookup)}) * 1000) > #{v}"
              when 'gteqdatetime'
                array.push "(EXTRACT(EPOCH FROM #{field_to_fqn(field, field_lookup)}) * 1000) >= #{v}"

              when 'isnull'
                if [1, true, 'true', 'TRUE', 'True'].include? v
                  array.push "#{field_to_fqn(field, field_lookup)} IS NULL"
                elsif [0, false, 'false', 'FALSE', 'False'].include? v
                  array.push "#{field_to_fqn(field, field_lookup)} IS NOT NULL"
                end

              when 'in'
                array.push "#{field_to_fqn(field, field_lookup)} IN ('#{v.join('\', \'')}')"
              end
            end
          end
        end

        # Return query string
        array.join(" AND ")
      end

      def process_order(sort_info, field_lookup = {})
        fields = sort_info['fields'].nil? ? [] : sort_info['fields']
        directions = sort_info['directions'].nil? ? [] : sort_info['directions']

        if fields.length != directions.length
          raise "fields count not same as direction"
        end

        array = []
        for i in 0..(fields.length - 1)
          array.push("#{field_to_fqn(fields[i], field_lookup)} #{directions[i]}")
        end

        array.join(",")
      end

      def parse_params(params)
        case params.class.to_s
        when "ActionController::Parameters"
          params.to_unsafe_h
        when "String"
          JSON.parse(params)
        when "Hash"
          params.with_indifferent_access
        when "Array"
          params.collect{ |c| parse_params(c) }
        else
          params
        end
      end
  end
end
