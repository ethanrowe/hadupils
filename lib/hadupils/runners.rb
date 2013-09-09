module Hadupils::Runners
  class Base
    attr_reader :params, :last_result, :last_status

    def initialize(params)
      @params = params
    end

    def command; end

    def execute!
      command_list = command
      if RUBY_VERSION < '1.9' and command_list[0].kind_of? Hash
        deletes = []
        overrides = {}
        begin
          command_list[0].each do |key, val|
            if ::ENV.has_key? key
              overrides[key] = ::ENV[key]
            else
              deletes << key
            end
            ::ENV[key] = val
          end
          Kernel.system(*command_list[1..-1])
        ensure
          overrides.each {|key, val| ::ENV[key] = val }
          deletes.each {|key| ::ENV.delete key }
        end
      else
        Kernel.system(*command_list)
      end
    end

    def wait!
      @last_result = execute!
      @last_status = $?
      if @last_result.nil?
        255
      else
        @last_status.exitstatus
      end
    end

    def self.run(*params)
      self.new(*params).wait!
    end
  end

  class Hive < Base
    def initialize(params, hive_aux_jars_path='')
      super(params)
      @hive_aux_jars_path = hive_aux_jars_path
    end

    def self.base_runner
      @base_runner || ::File.join(ENV['HIVE_HOME'], 'bin', 'hive')
    end

    def self.base_runner=(runner_path)
      @base_runner = runner_path
    end

    def command
      params.inject([env_overrides, self.class.base_runner]) do |result, param|
        if param.respond_to? :hive_opts
          result + param.hive_opts
        else
          result << param
        end
      end
    end

    def env_overrides
      e = {}
      settings = [@hive_aux_jars_path, ::ENV['HIVE_AUX_JARS_PATH']].reject do |val|
        val.nil? or val.strip == ''
      end
      if settings.length > 0
        e['HIVE_AUX_JARS_PATH'] = settings.join(',')
      end
      e
    end
  end
end
