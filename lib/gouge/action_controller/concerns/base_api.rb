# =============================================================================
# Copyright (c) 2010-2016 All Right Reserved, http://starqle.com/
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
# @file_name lib/gouge/active_model/concerns/base_api.rb
# @author Giovanni Sakti
# @email giosakti@starqle.com
# @company PT. Starqle Indonesia
# @note Gouge::BaseApi concern
# =============================================================================

module Gouge
  module BaseApi
    extend ::ActiveSupport::Concern

    included do
      append_before_action :scope_resource
      append_before_action :scope_member, unless: :collection_action?
      append_before_action :authorize_member, unless: :collection_action?

      # GET
      # Retrieve all resources
      def index
        @scope = process_grid(grid_params)
        render render_params.merge({
          serializer: serializer,
          items_type: :grid
        })
      end

      # GET :id
      # Retrieve existing resource
      def show
        render render_params
      end

      # GET new
      # Retrieve new resource
      def new
        render render_params
      end

      # POST
      # Create new resource
      def create
        @scope.update!(filtered_params)
        @scope.notifications[:success].add("", t('notifications.messages.create_success', resource: t(@scope.class.to_s.underscore)))
        render render_params
      end

      # GET :id/edit
      # Retrieve existing resource

      # PUT :id
      # Update existing resource
      def update
        @scope.update!(filtered_params)
        @scope.notifications[:success].add("", t('notifications.messages.update_success', resource: t(@scope.class.to_s.underscore)))
        render render_params
      end

      alias_method :edit, :show

      protected
        def render_params
          { json: @scope }
        end

      private
        def scope_resource
          # TODO: @giosakti namespace shouldn't be hardcoded
          @klass = "::#{self.class.name.split("::").first}::#{controller_name.demodulize.classify}".constantize
        rescue NameError => e
          @klass = nil
        ensure
          @scope = @klass
          @scope = policy_scope(@scope) unless @scope.nil?
        end

        def scope_member
          return if @scope.nil?
          if build_resource?
            @scope = @scope.new
          elsif find_resource?
            @scope = @scope.find(params[:id])
          end
        end

        def authorize_member
          return if @scope.nil?
          if build_resource? || find_resource?
            authorize @scope
          end
        end

        def filtered_params
          params.require(:data)
        end

        def grid_params
          params.to_unsafe_h.slice(
            :klass,
            :column_defs,
            :q,
            :filter_params,
            :page,
            :per_page,
            :sort_info,
            :enable_paging,
            :join_objects,
            :field_lookup,
            :custom_where_query,
            :group_by_query,
            :inner_join_query,
            :inner_where_query,
            :inner_group_query
          ).merge(
            column_defs:        (params[:column_defs] || self.class.try(:default_column_defs)),
            klass:              @scope,
            join_objects:       self.class.try(:join_objects),
            field_lookup:       self.class.try(:field_lookup),
            custom_where_query: self.class.try(:custom_where_query),
            group_by_query:     self.class.try(:group_by_query)
          )
        end
    end

    # Methods for identifying action.

    def build_resource?
      new_action?
    end

    def find_resource?
      member_action?
    end

    def collection_action?
      collection_actions.include?(params[:action])
    end

    def new_action?
      new_actions.include?(params[:action])
    end

    def member_action?
      params[:id].present?
    end

    def collection_actions
      %w(index search)
    end

    def new_actions
      %w(new create)
    end

    # Methods for overriding ActiveModelSerializer behavior: Use namespaced
    # serializer.

    def default_serializer_options
      { serializer_key => serializer }
    end

    def serializer_key
      collection_action? ? :each_serializer : :serializer
    end

    def serializer
      namespaced_serializer || active_model_serializer || default_serializer
    end

    def namespaced_serializer
      "#{namespace}::#{serializer_name}".constantize rescue nil
    end

    def active_model_serializer
      serializer_name.constantize rescue nil
    end

    def default_serializer
      ::ActiveModel::DefaultSerializer
    end

    def namespace
      self.class.to_s.deconstantize
    end

    def serializer_name
      return "#{controller_name.demodulize.classify}ArraySerializer" if collection_action?
      "#{controller_name.demodulize.classify}Serializer"
    end

    module ClassMethods
      # nop
    end
  end
end
