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
# @file_name lib/gouge/sortable_tree/sortable_tree.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note SortableTree module
# =============================================================================

module SortableTree
  extend ActiveSupport::Concern

  module ClassMethods
    # Execute changes that was supplied in array of movements
    # Array of movements sample:
    # [
    #   {
    #     id: d.id,
    #     parent_id: a.id,
    #     index: ...,
    #   },
    #   {
    #     id: d.id,
    #     parent_id: b.id,
    #     index: ...,
    #   },
    #   {
    #     id: c.id,
    #     parent_id: nil,
    #     index: ...,
    #   },
    #   {
    #     id: a.id,
    #     parent_id: d.id,
    #     index: ...,
    #   }
    # ]
    def execute_movements(movements)
      ActiveRecord::Base.transaction do
        if sequence
          movements.each do |movement|
            item = find(movement[:id])

            # Origin related variables
            ori_idx = item[sequence]
            ori_parent_id = item.parent_id
            ori_siblings = item.siblings

            # Destination related variables
            dst_idx = movement[:index].to_i
            dst_parent_id = movement[:parent_id]

            # Assign dummy seq to avoid uniqueness on ancestry
            item[sequence] = dst_idx + count + 1
            item.parent_id = dst_parent_id
            item.save!

            if ori_parent_id == dst_parent_id
              # Movement within the same parent (siblings)
              siblings = ori_siblings.where{__send__(my{sequence}).gteq( my{[ori_idx, dst_idx].min} ) & __send__(my{sequence}).lteq( my{[ori_idx, dst_idx].max} )}.all.sort!{|a, b| a[sequence] <=> b[sequence]}

              if dst_idx > ori_idx
                siblings.each do |sibling|
                  sibling[sequence] = sibling[sequence] - 1
                  sibling.save!
                end
              else
                siblings.reverse.each do |sibling|
                  sibling[sequence] = sibling[sequence] + 1
                  sibling.save!
                end
              end

            else
              # Move to different parent

              # Re-arrange origin siblings
              siblings = ori_siblings.where{id.not_eq( my{item.id} ) & __send__(my{sequence}).gteq( my{ori_idx} )}.to_a.sort!{|a, b| a[sequence] <=> b[sequence]}
              siblings.each do |sibling|
                sibling[sequence] = sibling[sequence] - 1
                sibling.save!
              end

              # Re-arrange destination siblings
              dst_siblings = item.siblings
              siblings = dst_siblings.where{id.not_eq( my{item.id} ) & __send__(my{sequence}).gteq( my{dst_idx} )}.to_a.sort!{|a, b| a[sequence] <=> b[sequence]}
              siblings.reverse.each do |sibling|
                sibling[sequence] = sibling[sequence] + 1
                sibling.save!
              end
            end

            # Assign item with real destination index
            item[sequence] = dst_idx
            item.save!
          end
        else
          movements.each do |movement|
            item = find(movement[:id])
            item.parent_id = movement[:parent_id]
            item.save!
          end
        end
      end
    end
  end

  #
  # INSTANCE METHOD
  #
  def update_with_movement!(params)
    ActiveRecord::Base.transaction do
      # Update attrbute except parent_id (it will be updated later)
      self.update!(params.except(:parent_id))

      # Execute movement if parent_id is changed
      unless params[:parent_id].eql? self.parent_id
        self.class.execute_movements([{
          id: self.id,
          parent_id: params[:parent_id],
          index: self.class.find_by(id: params[:parent_id]).try(:children).try(:count) || self.class.roots.count
        }])
      end

      self.reload
    end
  end

end

class ActiveRecord::Base
  def self.acts_as_sortable_tree(options = {})
    cattr_accessor :sequence
    self.sequence = options[:sequence].try(:to_sym) || false
    include SortableTree
  end
end
