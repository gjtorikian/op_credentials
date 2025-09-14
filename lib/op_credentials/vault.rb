# frozen_string_literal: true

require "json"
require "open3"

module OpCredentials
  class Vault
    attr_reader :name

    OP_VAULT_SECRETS = {}
    def initialize(name)
      @name = name
    end

    def load(tags: [ENV["RAILS_ENV"]])
      # To reduce the amount of API calls to 1Password, we can
      # grab one document that contains all the secrets we need
      if !compiling_assets? && !Rails.env.local?
        result = op_load_vault_into_env(tags: tags)
        if result.is_a?(Array)
          raise RuntimeError, "No items found in vault `#{@name}` for tags: #{tags}"
        end

        result["fields"].select { |f| f["value"] }.each do |field|
          load_vault_secret(field)
        end
      end
    end

    def fetch_secret(label:, default: nil, delete: true)
      if compiling_assets?
        "" # doesn't matter for asset compilation
      elsif !Rails.env.local?
        (delete ? OP_VAULT_SECRETS.delete(label) : OP_VAULT_SECRETS[label]) || raise("Secret `#{label}` not found in 1Password")
      else # look for it in credentials; if not, in env, if not, the default
        Rails.application.credentials.fetch(:label, ENV.fetch(label, default))
      end
    end

    private def op_load_vault_into_env(tags: [])
      cmd = "#{include_sudo}op item list --vault #{@name}#{include_tags(tags)}--format json | #{include_sudo}op item get - --reveal --format=json"
      stdout, stderr, status = Open3.capture3(cmd)
      raise "Failed to fetch `vault: #{@name}` for `tags: #{tags}` from 1Password: #{stderr}" unless status.success?

      format_op_result(stdout)
    end

    private def load_vault_secret(field)
      OP_VAULT_SECRETS[field["label"]] = field["value"].gsub("\\n", "\n")
    end

    private def within_console?
      Rails.const_defined?(:Console)
    end

    private def compiling_assets?
      !ENV.fetch("SECRET_KEY_BASE_DUMMY", nil).nil?
    end

    private def include_sudo
      Rails.env.production? || Rails.env.staging? ? "sudo -E " : ""
    end

    private def include_tags(tags = [])
      return " " if tags.nil?
      tags.compact!
      tags.any? ? " --tags #{tags.join(",")} " : " "
    end

    private def format_op_result(raw)
      json_objects = raw.scan(/\{.*?\}(?=\s*\{|\s*\z)/m).map { |obj| JSON.parse(obj) }
      json_objects.length == 1 ? json_objects.first : json_objects
    end
  end
end
