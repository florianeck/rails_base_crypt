module Rails
  module BaseCrypt

    mattr_accessor :level_1_key, :level_2_key, :keys_valid, :encoding_levels

    # self.encoding_levels = 2 TODO: update code to allow more than 2 loops of encoding
    self.level_1_key = ""
    self.level_2_key = ""
    self.keys_valid  = false

    # Chars to be encoded after converting data to Base64
    # this must be excact the string set used by Base64
    # TODO: Allow user to generate string in custom order and save it somewhere to overwrite this existing default order
    # TODO: add config setting where to load this string from to make encryption more unique
    CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890+\\\n="

    class << self
      #=
      def verify_keys
        if keys_valid != true
          chars_default = CHARS.split("")

          if self.level_1_key.size == CHARS.size && self.level_2_key.size == CHARS.size
            if self.level_1_key != self.level_2_key
              x1 = (self.level_1_key.split("") - chars_default)
              x2 = (self.level_2_key.split("") - chars_default)

              if (x1+x2).size == 0
                self.keys_valid = true

              else
                raise "Chars does not match with keys - following errors: \n#{x1.inspect}\n#{x2.inspect}"
              end

            else
              raise "Level 1 key must not be the same as level 2 key"
            end
          else
            raise "Key length must be exact #{CHARS.size}!"
          end
        else
          true
        end
      end

      def create_random_key
        # make sure that \n is always the last char in the key
        # otherwise things are crashing...
        (BaseCrypt::CHARS.split("") - ["\n"]).sort_by { rand }.join("")+"\n"
      end

      def base_crypt_settings_for_env(env = nil)
        k1 = self.create_random_key
        k2 = self.create_random_key
        output = [
          'BaseCrypt.level_1_key ='+ k1.inspect,
          'BaseCrypt.level_2_key ='+ k2.inspect
        ].join("\n")

        puts "Add this to your #{env.nil? ? 'application.rb' : env.to_s+'.rb'} file"
        puts output
      end


      def encode(data)
        if self.verify_keys
          yaml_data = YAML::dump(data)
          base_data = Base64.encode64(yaml_data)
          return self.encode_level_2(self.encode_level_1(base_data)  )
        else
          raise "Please verify keys.."
        end
      end

      def decode(string, default = nil)
        if self.verify_keys && string.is_a?(String) && !string.blank?
          yaml_data = Base64.decode64(self.decode_level_1(self.decode_level_2(string)))
          return YAML::load(yaml_data)
        else
          return default
        end
      end

      # maybe some day, there will be the options to use more encoding levels.... :-)
      [1,2].each do |i|

        define_method "level_#{i}_key=" do |key|
          eval("@@level_#{i}_key = key")
          self.keys_valid = false
        end

        define_method "encode_level_#{i}" do |string|
          result = ""
          key = self.send("level_#{i}_key").split("")
          string.split("").each do |s|
            position = key.index(s)
            result << (position.to_s.rjust(2, "0")+key[rand(key.size-1)])
          end

          return result
        end

        define_method "decode_level_#{i}" do |string|
          result = ""
          key = self.send("level_#{i}_key").split("")
          string.scan(/[0-9]{2}.{1}/).each do |s|
            result << key[s.first(2).to_i]
          end
          return result
        end
      end
    end
  end
end