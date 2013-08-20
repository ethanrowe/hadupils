module Hadupils::Runners
  class Base
    attr_reader :params, :last_result, :last_status

    def initialize(params)
      @params = params
    end

    def command; end

    def wait!
      @last_result = Kernel.system(*command)
      @last_status = $?
      if @last_result.nil?
        255
      else
        @last_status.exitstatus
      end
    end

    def self.run(params)
      self.new(params).wait!
    end
  end

  class Hive < Base
    def self.base_runner
      @base_runner || ::File.join(ENV['HIVE_HOME'], 'bin', 'hive')
    end

    def self.base_runner=(runner_path)
      @base_runner = runner_path
    end

    def command
      items = params.inject([self.class.base_runner]) do |result, param|
        if param.respond_to? :hive_opts
          result + param.hive_opts
        else
          result << param
        end
      end
    end
  end
end
