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
# @file_name lib/gouge/recurring_event.rb
# @author Raymond Ralibi
# @email ralibi@starqle.com
# @company PT. Starqle Indonesia
# @note RecurringEvent module
# =============================================================================

module Gouge
  module RecurringEvent
    extend ActiveSupport::Concern

    MINUTE_IN_SECONDS = 60
    HOUR_IN_SECONDS = MINUTE_IN_SECONDS * 60
    DAY_IN_SECONDS = HOUR_IN_SECONDS * 24
    WEEK_IN_SECONDS = DAY_IN_SECONDS * 7
    RECURRENCE_TYPES = %w(
      NO_RECURRENCE
      EVERY_N_DAYS
      EVERY_N_WEEKS
      EVERY_N_MONTHS
      EVERY_N_YEARS
      EVERY_DAYS_OF_WEEK
    )

    included do
      validates :recurrence_type,
        presence: true,
        inclusion: { in: RECURRENCE_TYPES }
    end

    module ClassMethods
      # Check whether array of events conflict with each other.
      # @param events [Object] array of events to be checked
      def find_conflicted_events(events)
        arr = []
        events.sort!{|a, b| a[:from_time_in_secs] <=> b[:from_time_in_secs]}
        events.each_with_index do |event, idx|
          if (idx + 1) < events.size
            next_event = events[idx + 1]
            if event[:thru_time_in_secs] > next_event[:from_time_in_secs]
              conflict_from_time_in_secs = next_event[:from_time_in_secs]
              conflict_thru_time_in_secs = [event[:thru_time_in_secs], next_event[:thru_time_in_secs]].min
              arr << {
                first_event_id: event[:event_object][:id],
                second_event_id: next_event[:event_object][:id],
                from_time_in_secs: conflict_from_time_in_secs,
                thru_time_in_secs: conflict_thru_time_in_secs,
                from_time: DateTime.strptime("#{conflict_from_time_in_secs}", '%s'),
                thru_time: DateTime.strptime("#{conflict_thru_time_in_secs}", '%s')
              }
            end
          end
        end

        arr
      end

      def event_to_hash(obj, from_time_in_secs, thru_time_in_secs)
        {
          event_object: obj,
          from_time_in_secs: from_time_in_secs,
          thru_time_in_secs: thru_time_in_secs
        }
      end
    end

    # Conditionals
    # --------------------

    def no_recurrence?
      self.recurrence_type == "NO_RECURRENCE"
    end

    def recur_every_n_days?
      self.recurrence_type == "EVERY_N_DAYS"
    end

    def recur_every_n_weeks?
      self.recurrence_type == "EVERY_N_WEEKS"
    end

    def recur_every_n_months?
      self.recurrence_type == "EVERY_N_MONTHS"
    end

    def recur_every_n_years?
      self.recurrence_type == "EVERY_N_YEARS"
    end

    def recur_every_days_of_week?
      self.recurrence_type == "EVERY_DAYS_OF_WEEK"
    end

    # Event Formulae
    # --------------------

    # Returns collection of events that was derived from a schedule.
    # @param from_time_in_secs [Integer] from time range in seconds
    # @param thru_time_in_secs [Integer] thru time range in seconds
    def events(from_time_in_secs = nil, thru_time_in_secs = nil, filter_events = [])
      # If from_time_in_secs is nil, use from_time attribute from the model.
      from_time_in_secs = DateTime.strptime("#{from_time_in_secs}", '%s').beginning_of_day.to_i if from_time_in_secs
      from_time_in_secs ||= self.from_time.beginning_of_day.to_i

      # If thru_time_in_secs is nil, use recurrence_end attribute from the model.
      # note: thru_time_in_secs may still be nil if no recurrence_end is specified
      # note: thru_time_in_secs is exclusive. substract with DAY_IN_SECONDS to
      # become inclusive (see arshaw fullcalendar docs)
      thru_time_in_secs = DateTime.strptime("#{thru_time_in_secs}", '%s').end_of_day.to_i - DAY_IN_SECONDS if thru_time_in_secs
      thru_time_in_secs = [thru_time_in_secs, self.recurrence_end.try(:end_of_day).try(:to_i)].compact.min

      arr = []
      self.fetch_events_time(from_time_in_secs, thru_time_in_secs).each do |e|
        event_from_time_in_secs = e +
          (self.from_time.hour * HOUR_IN_SECONDS) +
          (self.from_time.min * MINUTE_IN_SECONDS)
        event_thru_time_in_secs = event_from_time_in_secs + self.duration

        unless filter_events.include? event_from_time_in_secs
          arr << self.class.event_to_hash(self, event_from_time_in_secs, event_thru_time_in_secs)
        end
      end

      arr
    end

    # Returns collection of events time in seconds
    # @param lfe [Integer] left edge / from time range in seconds
    # @param rge [Integer] right edge / thru time range in seconds
    def fetch_events_time(lfe, rge)
      # collect from_time beginning of day (in seconds)
      frt = self.from_time.beginning_of_day.to_i

      case self.recurrence_type
      when "NO_RECURRENCE"
        self.no_recurrence_dates(lfe, rge, frt)
      when "EVERY_N_DAYS"
        self.recur_every_n_days_dates(lfe, rge, frt)
      when "EVERY_N_WEEKS"
        self.recur_every_n_weeks_dates(lfe, rge, frt)
      when "EVERY_N_MONTHS"
        self.recur_every_n_months_dates(lfe, rge, frt)
      when "EVERY_N_YEARS"
        self.recur_every_n_years_dates(lfe, rge, frt)
      when "EVERY_DAYS_OF_WEEK"
        self.recur_every_days_of_week_dates(lfe, rge, frt)
      else
        []
      end
    end

    protected
      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def no_recurrence_dates(lfe, rge, frt)
        # in no-recurrence rge maybe null, therefore set rge with
        # from_time end of day.
        rge ||= self.from_time.end_of_day.to_i
        return [frt] if lfe <= frt && frt <= rge
        []
      end

      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def recur_every_n_days_dates(lfe, rge, frt)
        interval = self.recur_every_n_days
        arr = []
        (frt..rge).step(interval * DAY_IN_SECONDS) do |cis|
          arr << cis if lfe <= cis
        end
        arr
      end

      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def recur_every_n_weeks_dates(lfe, rge, frt)
        interval = self.recur_every_n_weeks
        arr = []
        (frt..rge).step(interval * WEEK_IN_SECONDS) do |cis|
          arr << cis if lfe <= cis
        end
        arr
      end

      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def recur_every_n_months_dates(lfe, rge, frt)
        interval = self.recur_every_n_months
        arr = []
        cis = frt
        until cis > rge
          arr << cis if lfe <= cis
          cis = (interval.month.from_now DateTime.strptime("#{cis}",'%s')).to_i
        end
        arr
      end

      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def recur_every_n_years_dates(lfe, rge, frt)
        interval = self.recur_every_n_years
        arr = []
        cis = frt
        until cis > rge
          arr << cis if lfe <= cis
          cis = (interval.year.from_now DateTime.strptime("#{cis}", '%s')).to_i
        end
        arr
      end

      # @param lfe [Integer] left edge / from time range in seconds
      # @param rge [Integer] right edge / thru time range in seconds
      # @param frt [Integer] start of the event (from_time) (in seconds)
      def recur_every_days_of_week_dates(lfe, rge, frt)
        wdays = self.recur_every_days_of_week.split(',').collect(&:to_i)
        arr = []
        # Iterate each single day from wdays
        wdays.each do |wday|
          # First wday date after given date
          cis = frt + (((wday - self.from_time.wday) % 7) * DAY_IN_SECONDS)
          until cis > rge
            arr << cis if lfe <= cis
            cis += WEEK_IN_SECONDS
          end
        end
        arr
      end
  end
end

class ActiveRecord::Base
  def self.acts_as_recurring_event(options = {})
    validates :recurrence_end, presence: true, unless: :no_recurrence?
    validates :recur_every_n_days, presence: true, if: :recur_every_n_days?
    validates :recur_every_n_weeks, presence: true, if: :recur_every_n_weeks?
    validates :recur_every_n_months, presence: true, if: :recur_every_n_months?
    validates :recur_every_n_years, presence: true, if: :recur_every_n_years?
    validates :recur_every_days_of_week, presence: true, if: :recur_every_days_of_week?
    include ::Gouge::RecurringEvent
  end
end
