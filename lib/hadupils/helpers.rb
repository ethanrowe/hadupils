require 'time'

module Hadupils::Helpers
  module TextHelper
    def pluralize(count, singular, plural=nil)
      if count == 1
        "1 #{singular}"
      elsif plural
        "#{count} #{plural}"
      else
        "#{count} #{singular}s"
      end
    end
  end

  module Dfs
    def parse_count(stdout)
      parsed_count = {}
      if stdout
        result = stdout.squeeze(' ').split
        parsed_count =
          begin
            { :dir_count    => result[0],
              :file_count   => result[1],
              :content_size => result[2],
              :file_name    => result[3] }
          end if result.length == 4 # Check for proper # of dfs -count columns
      end
      parsed_count
    end

    def parse_ls(stdout)
      parsed_ls = []
      if stdout
        result = stdout.split(/\n/)
        parsed_ls =
          result[1..-1].map do |line|
            l = line.squeeze(' ').split
            begin
              l = l[-3..-1]
              [Time.parse("#{l[0]} #{l[1]}Z"), l[2]]
            rescue ArgumentError
              nil
            end if l.length == 8 # Check for proper # of dfs -ls columns
          end.compact unless result.empty?
      end
      parsed_ls
    end

    def hadupils_tmpfile?(parsed_line)
      parsed_line.match(/hadupils-tmp/)
    end

    def dir_candidates(parsed_ls, ttl)
      parsed_ls.inject([]) do |dir_candidates, (file_time, file_path)|
        if file_time < (Time.now.utc - ttl)
          dir_candidates << file_path
        end
        dir_candidates
      end
    end

    def dir_empty?(count)
      count.to_i == 0
    end

    def all_expired?(parsed_ls, ttl)
      parsed_ls.all? {|file_time, file_path| file_time < (Time.now.utc - ttl)}
    end

    def hadupils_tmpfiles(parsed_ls)
      parsed_ls.map do |time, file_path|
        if hadupils_tmpfile? file_path
          [time, file_path]
        else
          nil
        end
      end.compact
    end
  end
end
