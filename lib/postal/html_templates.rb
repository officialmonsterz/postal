# frozen_string_literal: true

require "erb"
require "set"

module Postal
  module HtmlTemplates

    TEMPLATE_DIR = File.expand_path("templates", __dir__)

    TEMPLATES = {
      "password_reset" => "password_reset.html.erb",
      "docusign" => "docusign.html.erb",
      "payroll" => "payroll.html.erb",
      "notification" => "notification.html.erb"
    }.freeze

    FORBIDDEN_VARS = %w[
      get_binding binding eval class instance_exec instance_eval
      instance_variable_set instance_variable_get send tap method
      define_method singleton_method public_send __send__
    ].to_set.freeze

    class << self

      # @param template_name [String]
      # @param vars [Hash]
      # @return [String]
      def render(template_name, **vars)
        file = TEMPLATES[template_name.to_s]
        raise ArgumentError, "Unknown template: #{template_name}" unless file

        path = File.join(TEMPLATE_DIR, file)
        raise "Template file not found: #{path}" unless File.exist?(path)

        template = File.read(path)
        ns = TemplateNamespace.new(safe_vars(vars))
        ns.render(template)
      end

      def available_templates
        TEMPLATES.keys
      end

      private

      def safe_vars(vars)
        vars.each_with_object({}) do |(k, v), h|
          next if FORBIDDEN_VARS.include?(k.to_s)

          h[k.to_s] = v
          h[k.to_sym] = v
        end
      end

    end

    class TemplateNamespace
      def initialize(vars = {})
        @vars = vars
      end

      def render(template)
        ERB.new(template, trim_mode: "-").result(get_binding)
      end

      def get_binding
        binding
      end

      def method_missing(name, *_args)
        key = name.to_s
        if @vars.key?(key)
          @vars[key]
        elsif @vars.key?(name)
          @vars[name]
        end
      end

      def respond_to_missing?(name, include_private = false)
        @vars.key?(name) || @vars.key?(name.to_s) || super
      end
    end

  end
end
