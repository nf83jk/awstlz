require 'aws-sdk'
require 'yaml'

module Util
  module AwsTlz
    class Rds
      class << self

        def loadConfigYaml(config_path, config_alias)
          # create configuration yaml path
          configyamlfile = config_path << '/' << config_alias << '.yml'
          # load configuration yaml file
          configcreds = YAML.load(File.read(configyamlfile))

          return configcreds
        end

        def getClient(creds)
          # Initialize AWS::RDS::Client
          client = Aws::RDS::Client.new(
            region: creds['region'],
            access_key_id: creds['access_key_id'],
            secret_access_key: creds['secret_access_key'],
          ) 

          return client
        end

        def getResource(creds)
          # Initialize AWS::RDS::Client
          client = self.getClient(creds)

          # Initialise AWS::RDS::Resource
          resource = Aws::RDS::Resource.new(
            client: client
          )
          
          return resource
        end

        def getInstance(creds, instance_id)
          resource = self.getResource(creds)
          instance = resource.db_instance(instance_id)

          return instance
        end

        def setInstance(creds, server_info, action)
          result = nil

          # 設定情報から重要項目を抽出
          service_type = server_info['service_type']
          instance_id  = server_info['instance_id']

          # [RDS]復旧用スナップショット名の確定
          final_snapshot = "fss-#{service_type}-#{instance_id}"

          # 復旧起動時のオプションを確定
          unless server_info['restore_option'].nil?
            restore_option = server_info['restore_option']
          else
            restore_option = {}
          end
          restore_option[:db_instance_identifier] = "#{instance_id}"
          restore_option[:db_snapshot_identifier] = "#{final_snapshot}"

          # 復旧起動時の追加設定オプションを確定
          unless server_info['modify_option'].nil?
            modify_option = server_info['modify_option']
          else
            modify_option = {}
          end
          modify_option[:db_instance_identifier] = "#{instance_id}"

          # 状態確認時のオプション設定
          unless server_info['describe_option'].nil?
            describe_option = server_info['describe_option']
          else
            describe_option = {}
          end
          describe_option[:db_instance_identifier] = "#{instance_id}"

          # スナップショット削除時のオプションを確定
          delete_snapshot_option = {};
          delete_snapshot_option[:db_snapshot_identifier] = "#{final_snapshot}"

          # RDSクライアントの初期化
          client = self.getClient(creds)

          case action
          when 'start'
            # 1. 復旧用スナップショットから復旧する方式でインスタンスを作成
            client.restore_db_instance_from_db_snapshot(restore_option)

            # 2. 作成が完了するまでの間、処理を待機
            status = ''
            until status == 'available'
              print '.'
              sleep 20

              status = self.describeInstanceStatus(client, describe_option)
            end
            print '! '

            # 3. セキュリティグループ・パラメータグループを更新
            client.modify_db_instance(modify_option)
            sleep 20

            # 4. インスタンスを再起動して更新を反映
            self.setInstance(creds, server_info, 'reboot')

            # 5. 復旧用スナップショットを削除
            client.delete_db_snapshot(delete_snapshot_option)

            result = true
          when 'stop'
            # 1. 復旧用スナップショットを作成してインスタンスを削除
            client.delete_db_instance({
              db_instance_identifier: "#{instance_id}",
              skip_final_snapshot: false,
              final_db_snapshot_identifier: "#{final_snapshot}",
            })

            result = true
          when 'reboot'
            # 1. インスタンスを再起動
            client.reboot_db_instance({
              db_instance_identifier: "#{instance_id}",
            })

            result = true
          when 'status'
            status = ''
            # 1. インスタンスの状態を取得
            status = self.describeInstanceStatus(client, describe_option)

            result = status
          when 'endpoint'
            endpoint = ''
            # 1. エンドポイントの状態を取得
            endpoint = self.describeInstanceEndpoint(client, describe_option)
            result = endpoint
          else
            result = "Nothing to do."
          end

          return result

        rescue => e
          raise
        end

        def describeInstance(client, describe_option)
          describe = nil
          begin
            # インスタンスの状態を取得
            describe = client.describe_db_instances(describe_option)
          rescue
            describe = nil
          end            
          return describe
        end

        def describeInstanceStatus(client, describe_option)
          status = ''
          begin
            describe = self.describeInstance(client, describe_option)
            status = describe.db_instances[0].db_instance_status
          rescue
            status = 'not-found'
          end
          return status
        end

        def describeInstanceEndpoint(client, describe_option)
          endpoint = ''
          begin
            describe = self.describeInstance(client, describe_option)
            endpoint = describe.db_instances[0].endpoint.address
          rescue
            endpoint = 'not-found'
          end
          return endpoint
        end
      end #class self
    end #class
  end # module
end # module
