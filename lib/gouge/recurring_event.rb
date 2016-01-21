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

    NO_REPEAT = 1
    REPEAT_TYPE_EVERY_N_DAYS = 2
    REPEAT_TYPE_EVERY_N_WEEKS = 3
    REPEAT_TYPE_EVERY_N_MONTHS = 4
    REPEAT_TYPE_EVERY_N_YEARS = 5
    REPEAT_TYPE_EVERY_DAYS_OF_WEEK = 6
    REPEAT_TYPES = [
      {id: NO_REPEAT, name: "No repeat"},
      {id: REPEAT_TYPE_EVERY_N_DAYS, name: "Every n days"},
      {id: REPEAT_TYPE_EVERY_N_WEEKS, name: "Every n weeks"},
      {id: REPEAT_TYPE_EVERY_N_MONTHS, name: "Every n months"},
      {id: REPEAT_TYPE_EVERY_N_YEARS, name: "Every n years"},
      {id: REPEAT_TYPE_EVERY_DAYS_OF_WEEK, name: "Every days of week"}
    ]

    module ClassMethods
      # Check whether array of events conflict with each others.
      # @param events [Object] array of events to be checked
      def find_conflicted_events(events)
        arr = []
        events.sort!{|a, b| a[:start_time] <=> b[:start_time]}
        events.each_with_index do |event, i|
          if (i+1) < events.size
            next_event = events[i+1]
            if event[:end_time] > next_event[:start_time]
              conflict_start_time = next_event[:start_time]
              conflict_end_time = [event[:end_time], next_event[:end_time]].min
              arr << {
                first_event_id: event[:event_object][:id],
                second_event_id: next_event[:event_object][:id],
                start_time: conflict_start_time,
                end_time: conflict_end_time,
                start_date: Time.at(conflict_start_time),
                end_date: Time.at(conflict_end_time)
              }
            end
          end
        end

        arr
      end

      def event_to_hash(obj, start_time, end_time)
        {
          event_object: obj,
          start_time: start_time,
          end_time: end_time
        }
      end
    end

    # Conditionals
    # --------------------

    def no_repeat?
      self.repeat_type == NO_REPEAT
    end

    def repeat_every_n_days?
      self.repeat_type == REPEAT_TYPE_EVERY_N_DAYS
    end

    def repeat_every_n_weeks?
      self.repeat_type == REPEAT_TYPE_EVERY_N_WEEKS
    end

    def repeat_every_n_months?
      self.repeat_type == REPEAT_TYPE_EVERY_N_MONTHS
    end

    def repeat_every_n_years?
      self.repeat_type == REPEAT_TYPE_EVERY_N_YEARS
    end

    def repeat_every_days_of_week?
      self.repeat_type == REPEAT_TYPE_EVERY_DAYS_OF_WEEK
    end

    # Event Formulae
    # --------------------

    # Returns collection of events that was derived from a schedule.
    # @param start_time [Integer] start of time range in seconds
    # @param end_time [Integer] end of time range in seconds
    def events(start_time = nil, end_time = nil, filter_events = [])
      # if start_time is nil, use from_date attribute from the schedule.
      start_time = (start_time.present? ? Time.at(start_time) : self.from_date).beginning_of_day.to_i

      # if end_time is nil, use repeat_end attribute from the schedule.
      # note: end_time may still nil if no repeat is specified.
      # note: end_time is exclusive. substract with DAY_IN_SECOND to
      # become inclusive (see arshaw fullcalendar docs)
      end_time = [
        (end_time.present? ? Time.at(end_time).end_of_day.to_i - DAY_IN_SECOND : nil),
        self.repeat_end.try(:end_of_day).try(:to_i)
      ].compact.min

      arr = []
      self.fetch_events_time(start_time, end_time).each do |e|
        event_start_time = e + self.from_date.hour * HOUR_IN_SECOND +
          self.from_date.min * MINUTE_IN_SECOND
        event_end_time = event_start_time + self.duration

        unless filter_events.include? event_start_time
          arr << self.class.event_to_hash(self, event_start_time, event_end_time)
        end
      end

      arr
    end

    # Returns collection of events time in seconds
    # @param lfe [Integer] left edge / start of time range (in seconds)
    # @param rge [Integer] right edge / end of time range (in seconds)
    def fetch_events_time(lfe, rge)
      # collect from_date beginning of day (in seconds)
      frd = self.from_date.beginning_of_day.to_i

      case self.repeat_type
      when NO_REPEAT
        self.no_repeat_dates(lfe, rge, frd)
      when REPEAT_TYPE_EVERY_N_DAYS
        self.repeat_every_day_dates(lfe, rge, frd)
      when REPEAT_TYPE_EVERY_N_WEEKS
        self.repeat_every_week_dates(lfe, rge, frd)
      when REPEAT_TYPE_EVERY_N_MONTHS
        self.repeat_every_month_dates(lfe, rge, frd)
      when REPEAT_TYPE_EVERY_N_YEARS
        self.repeat_every_year_dates(lfe, rge, frd)
      when REPEAT_TYPE_EVERY_DAYS_OF_WEEK
        self.repeat_every_days_of_week_dates(lfe, rge, frd)
      else
        []
      end
    end

    protected

      # no-repeat doesn't have repeat_end
      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def no_repeat_dates(lfe, rge, frd)
        # in no-repeat rge maybe null, therefore set rge with
        # from_date end of day.
        rge ||= self.from_date.end_of_day.to_i
        return [frd] if lfe <= frd && frd <= rge
        []
      end

      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def repeat_every_day_dates(lfe, rge, frd)
        interval = self.repeat_every_n_days
        arr = []
        (frd..rge).step(interval * DAY_IN_SECOND) do |cis|
          arr << cis if lfe <= cis
        end
        arr
      end

      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def repeat_every_week_dates(lfe, rge, frd)
        interval = self.repeat_every_n_weeks
        arr = []
        (frd..rge).step(interval * WEEK_IN_SECOND) do |cis|
          arr << cis if lfe <= cis
        end
        arr
      end

      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def repeat_every_month_dates(lfe, rge, frd)
        interval = self.repeat_every_n_months
        arr = []
        cis = frd
        until cis > rge
          arr << cis if lfe <= cis
          cis = (interval.month.from_now DateTime.strptime("#{cis}",'%s')).to_i
        end
        arr
      end

      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def repeat_every_year_dates(lfe, rge, frd)
        interval = self.repeat_every_n_years
        arr = []
        cis = frd
        until cis > rge
          arr << cis if lfe <= cis
          cis = (interval.year.from_now DateTime.strptime("#{cis}", '%s')).to_i
        end
        arr
      end

      # @param lfe [Integer] left edge / start of time range (in seconds)
      # @param rge [Integer] right edge / end of time range (in seconds)
      # @param frd [Integer] start of the event (from_date) (in seconds)
      def repeat_every_days_of_week_dates(lfe, rge, frd)
        wdays = self.repeat_every_days_of_week.split(',').collect(&:to_i)
        arr = []
        # Iterate each single day from wdays
        wdays.each do |wday|
          # First wday date after given date
          cis = frd + ( ( ( wday - self.from_date.wday ) % 7 ) * DAY_IN_SECOND)
          until cis > rge
            arr << cis if lfe <= cis
            cis += WEEK_IN_SECOND
          end
        end
        arr
      end
  end
end

class ActiveRecord::Base
  def self.acts_as_recurring_event(options = {})
    validates_presence_of :repeat_end, unless: :no_repeat?
    validates_presence_of :repeat_every_n_days, if: :repeat_every_n_days?
    validates_presence_of :repeat_every_n_weeks, if: :repeat_every_n_weeks?
    validates_presence_of :repeat_every_n_months, if: :repeat_every_n_months?
    validates_presence_of :repeat_every_n_years, if: :repeat_every_n_years?
    validates_presence_of :repeat_every_days_of_week, if: :repeat_every_days_of_week?
    include ::Gouge::RecurringEvent
  end
end
