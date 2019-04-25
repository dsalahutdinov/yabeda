# frozen_string_literal: true

require "yabeda/metric"
require "yabeda/counter"
require "yabeda/gauge"
require "yabeda/histogram"
require "yabeda/group"
require "yabeda/dsl/metric_builder"

module Yabeda
  # DSL for ease of work with Yabeda
  module DSL
    # rubocop: disable Style/Documentation
    module ClassMethods
      # Block for grouping and simplifying configuration of related metrics
      def configure(&block)
        class_exec(&block)
        @group = nil
      end

      # Define the actions that should be performed
      def collect(&block)
        ::Yabeda.collectors.push(block)
      end

      # Specify metric category or group for all consecutive metrics in this
      # +configure+ block.
      # On most adapters it is only adds prefix to the metric name but on some
      # (like NewRelic) it is treated individually and has a special meaning.
      def group(group_name)
        @group = group_name
        return unless block_given?

        yield
        @group = nil
      end

      # Register a growing-only counter
      def counter(*args, **kwargs, &block)
        metric = MetricBuilder.new(Counter).build(args, kwargs, @group, &block)
        register_metric(metric)
      end

      # Register a gauge
      def gauge(*args, **kwargs, &block)
        metric = MetricBuilder.new(Gauge).build(args, kwargs, @group, &block)
        register_metric(metric)
      end

      # Register a histogram
      def histogram(*args, **kwargs, &block)
        metric = MetricBuilder.new(Histogram).build(args, kwargs, @group, &block)
        register_metric(metric)
      end

      private

      def register_metric(metric)
        name = [metric.group, metric.name].compact.join("_")
        return if ::Yabeda.metrics.key?(name)

        ::Yabeda.define_singleton_method(name) { metric }
        ::Yabeda.metrics[name] = metric
        ::Yabeda.adapters.each_value { |adapter| adapter.register!(metric) }
        register_group_for(metric) if metric.group
        metric
      end

      def register_group_for(metric)
        group = ::Yabeda.groups[metric.group]

        if group.nil?
          group = Group.new(metric.group)
          ::Yabeda.groups[metric.group] = group
          ::Yabeda.define_singleton_method(metric.group) { group }
        end

        group.register_metric(metric)
      end
    end
    # rubocop: enable Style/Documentation
  end
end
