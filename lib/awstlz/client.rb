require 'awstlz/common'
require 'yaml'
require 'util/awstlz/ec2'
require 'util/awstlz/rds'
require 'util/awstlz/elasticache'

module AwsTlz
  class Client
    @dir_info = nil
    @base_dir = nil

    def initialize(ini_base_dir)
      @dir_info = AwsTlz::Common.getDirInfo()
      @base_dir = ini_base_dir
    end 

    def doSetInstance(account_name, server_name, action)

      instance_info = nil

      status = nil
      unless action.nil?
          status = action
          if action == 'all'
            status = 'status'
          end
      end

      # アカウントディレクトリの走査
      accounts_dir = @base_dir + @dir_info[:etc] + @dir_info[:accounts] + '/'
      Dir.glob(accounts_dir + '*') { | account_info |
        # アカウント名の抽出
        dir_account_name = account_info.gsub(accounts_dir, '')

        # 指定されたアカウント名と異なる場合、次を走査
        unless account_name.nil?
          next if account_name != dir_account_name
        end

        # アカウント用設定ファイル名を確定
        dir_account_yaml = account_info + '/' + dir_account_name + '.yml'
        # 指定されたファイルが存在しない場合、次を走査
        next unless File.exist?(dir_account_yaml)

        # サーバディレクトリの走査
        servers_dir = account_info + @dir_info[:servers] + '/'
        Dir.glob(servers_dir + '*') { | server_info |
          # サーバー名の抽出
          dir_server_name = server_info.gsub(servers_dir, '').gsub('.yml', '')

          # 指定されたサーバ名と異なる場合、次を走査
          unless server_name.nil?
            next if server_name != dir_server_name
          end

          # サーバ用設定ファイル名を確定
          dir_server_yaml = server_info
          # 指定されたファイルが存在しない場合、次を走査
          next unless File.exist?(dir_server_yaml)

          instance_info = {
            account: YAML.load(File.read(dir_account_yaml)),
            server: YAML.load(File.read(dir_server_yaml)),
          }

          unless status.nil?
            begin
              # サーバ名・サービス・アクションを表示
              print dir_account_name
              print '::' + dir_server_name
              print '(' + instance_info[:server]['service_type'] + ')'
              print '.' + status + ' => '

              # 対象サーバへのアクションを実行
              instance_result = setInstance(instance_info, status)
              print instance_result
              puts
            rescue
            end
          end
        } # Dir.glob(servers_dir ...
      } # Dir.glob(accounts_dir ...

      return instance_info
    end

    def setInstance(instance_info, status)
      result = 0

      # 設定情報を分離
      account_info = instance_info[:account]
      server_info  = instance_info[:server]

      # サービスを確定
      if server_info['service_type'].nil? || status.nil?
        return 0
      end
#      puts server_info['service_type'] + ':' + status

      # サービス毎にインスタンス制御用メソッドを実行
      result = 
        case server_info['service_type']
          when 'ec2' then
            Util::AwsTlz::Ec2.setInstance(account_info, server_info, status)
          when 'rds' then
            Util::AwsTlz::Rds.setInstance(account_info, server_info, status)
          when 'elasticache' then
            Util::AwsTlz::ElastiCache.setInstance(account_info, server_info, status)
          else empty
        end

      return result
    end

  end
end
