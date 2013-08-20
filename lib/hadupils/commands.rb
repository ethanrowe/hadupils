module Hadupils::Commands
  def self.run(command, params)
    handler = handler_for command
    handler.run params
  end

  def self.handler_for(command)
    @handlers and @handlers[command.downcase.to_sym]
  end

  def self.register_handler(command, handler)
    @handlers ||= {}
    @handlers[command.downcase.to_sym] = handler
  end

  class SimpleCommand
    def self.run(params)
      self.new.run params
    end
  end

  module HadoopExt
    def hadoop_ext
      @hadoop_ext ||= Hadupils::Extensions::Flat.new(Hadupils::Search.hadoop_assets)
    end
  end

  module UserConf
    def user_config
      @user_config ||= Hadupils::Extensions::Static.new(Hadupils::Search.user_config)
    end
  end

  class Hive < SimpleCommand
    include HadoopExt
    include UserConf

    def assemble_parameters(parameters)
      user_config.hivercs + hadoop_ext.hivercs + parameters
    end

    def run(parameters)
      Hadupils::Runners::Hive.run assemble_parameters(parameters)
    end
  end

  register_handler :hive, Hive
end
