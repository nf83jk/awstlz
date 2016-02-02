
module AwsTlz
  class Common
    @dir_info = {
      etc:      '/etc',
      lib:      '/lib',
      bin:      '/bin',
      accounts: '/accounts', # etc_dir/
      servers:  '/servers',  # etc_dir/accounts_dir/*/servers_dir
    }

    class << self

      def getDirInfo
        return @dir_info
      end

    end
  end
end
