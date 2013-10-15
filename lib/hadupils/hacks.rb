if RUBY_VERSION < '2.0'
  class String
    def randcase
      dup.split('').map do |char|
        if rand(1..10) > 5
          char.upcase
        else
          char.downcase
        end
      end.join
    end
  end
else
  module Hadupils
    module Hacks
      refine ::String do
        def randcase
          dup.split('').map do |char|
            if rand(1..100) > 50
              char.upcase
            else
              char.downcase
            end
          end.join
        end
      end
    end
  end
end
