module Hadupils::Runners
  class Base
    attr_reader :params, :last_result, :last_status

    def initialize(params)
      @params = params
    end

    def self.run(*params)
      self.new(*params).wait!
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
      last_exitstatus
    end

    def last_exitstatus
      if @last_result.nil?
        255
      else
        @last_status.exitstatus
      end
    end
  end

  class Hadoop < Base
    class << self; attr_writer :base_runner; end

    def self.base_runner
      @base_runner || ::File.join(ENV['HADOOP_HOME'], 'bin', 'hadoop')
    end

    def command
      params.inject([self.class.base_runner]) do |result, param|
        if param.respond_to? :hadoop_opts
          result + param.hadoop_opts
        else
          result << param
        end
      end
    end
  end

  class Hive < Base
    class << self; attr_writer :base_runner; end

    def initialize(params, hive_aux_jars_path='')
      super(params)
      @hive_aux_jars_path = hive_aux_jars_path
    end

    def self.base_runner
      @base_runner || ::File.join(ENV['HIVE_HOME'], 'bin', 'hive')
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
      env = {}
      settings = [@hive_aux_jars_path, ::ENV['HIVE_AUX_JARS_PATH']].reject do |val|
        val.nil? || val.strip.empty?
      end
      if settings.length > 0
        env['HIVE_AUX_JARS_PATH'] = settings.join(',')
      end
      env
    end
  end

  class Subcommand < Base
    def command
      params
    end
  end
end
