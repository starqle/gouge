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
# @file_name lib/gouge/sortable_tree.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note SortableTree module
# =============================================================================

module Gouge
  module SortableTree
    extend ActiveSupport::Concern

    module ClassMethods
      # Execute changes that was supplied in array of movements
      # Array of movements sample:
      # [
      #   {
      #     id: d.id,
      #     parent_id: a.id,
      #     dest_seq: ...
      #   },
      #   {
      #     id: d.id,
      #     parent_id: b.id,
      #     dest_seq: ...
      #   },
      #   {
      #     id: c.id,
      #     parent_id: nil,
      #     dest_seq: ...
      #   },
      #   {
      #     id: a.id,
      #     parent_id: d.id,
      #     dest_seq: ...
      #   }
      # ]
      def execute_movements(movements)
        ActiveRecord::Base.transaction do
          if sortable_tree_sequence
            movements.each do |movement|
              item = find(movement[:id])

              # Origin related variables
              src_parent_id = item.parent_id
              src_seq = item[sortable_tree_sequence]
              src_siblings = item.siblings

              # Destination related variables
              dest_parent_id = movement[:parent_id]
              dest_seq = movement[:dest_seq].to_i

              # Assign dummy seq to avoid uniqueness on ancestry
              item.update!(
                parent_id: dest_parent_id,
                "#{sortable_tree_sequence}" => dest_seq + self.count + 1
              )

              # Move within same parent (siblings)
              if src_parent_id == dest_parent_id
                siblings = src_siblings
                  .where("""
                    #{item.class.table_name}.#{sortable_tree_sequence} > #{[src_seq, dest_seq].min}
                    AND #{item.class.table_name}.#{sortable_tree_sequence} < #{[src_seq, dest_seq].max}
                  """)
                  .to_a
                  .sort!{ |a, b| a[sortable_tree_sequence] <=> b[sortable_tree_sequence]}

                if dest_seq > src_seq
                  siblings.each do |sibling|
                    sibling.update!(
                      "#{sortable_tree_sequence}" => sibling[sortable_tree_sequence] - 1)
                  end
                else
                  siblings.reverse.each do |sibling|
                    sibling.update!(
                      "#{sortable_tree_sequence}" => sibling[sortable_tree_sequence] + 1)
                  end
                end
              else # Move to different parent
                # Re-arrange source siblings
                siblings = src_siblings
                  .where("""
                    #{item.class.table_name}.id != '#{item.id}'
                    AND #{item.class.table_name}.#{sortable_tree_sequence} > #{src_seq}
                  """)
                  .to_a
                  .sort!{|a, b| a[sortable_tree_sequence] <=> b[sortable_tree_sequence]}

                siblings.each do |sibling|
                  sibling.update!(
                    "#{sortable_tree_sequence}" => sibling[sortable_tree_sequence] - 1)
                end

                # Re-arrange destination siblings
                dest_siblings = item.siblings
                siblings = dest_siblings
                  .where("""
                    #{item.class.table_name}.id != '#{item.id}'
                    AND #{item.class.table_name}.#{sortable_tree_sequence} > #{dest_seq}
                  """)
                  .to_a
                  .sort!{|a, b| a[sortable_tree_sequence] <=> b[sortable_tree_sequence]}

                siblings.reverse.each do |sibling|
                  sibling.update!(
                    "#{sortable_tree_sequence}" => sibling[sortable_tree_sequence] + 1)
                end
              end

              # Assign real seq
              item.update!("#{sortable_tree_sequence}" => dest_seq)
            end
          else
            movements.each do |movement|
              item = find(movement[:id])
              item.update!(parent_id: movement[:parent_id])
            end
          end
        end
      end
    end

    def update_with_movement!(params)
      ActiveRecord::Base.transaction do
        # Update attrbute except parent_id (it will be updated later)
        self.update!(params.except(:parent_id))

        # Execute movement if parent_id is changed
        unless params[:parent_id].eql? self.parent_id
          if params[:parent_id]
            dest_seq = self.class.find(params[:parent_id]).children.count
          else
            dest_seq = self.class.roots.count
          end
          self.class.execute_movements([{
            id: self.id,
            parent_id: params[:parent_id],
            dest_seq: dest_seq
          }])
        end

        self.reload
      end
    end
  end
end

class ActiveRecord::Base
  def self.acts_as_sortable_tree(options = {})
    cattr_accessor :sortable_tree_sequence
    self.sortable_tree_sequence = options[:sequence].try(:to_sym)
    include ::Gouge::SortableTree
  end
end
