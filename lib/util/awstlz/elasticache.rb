require 'aws-sdk'
require 'yaml'

module Util
  module AwsTlz
    class ElastiCache
      class << self

        def loadConfigYaml(config_path, config_alias)
          # create configuration yaml path
          configyamlfile = config_path << '/' << config_alias << '.yml'
          # load configuration yaml file
          configcreds = YAML.load(File.read(configyamlfile))

          return configcreds
        end

        def getClient(creds)
          # Initialize AWS::ElastiCache::Client
          client = Aws::ElastiCache::Client.new(
            region: creds['region'],
            access_key_id: creds['access_key_id'],
            secret_access_key: creds['secret_access_key'],
          ) 

          return client
        end

        def setInstance(creds, server_info, action)
          result = nil

          # 設定情報から重要項目を抽出
          service_type = server_info['service_type']
          instance_id  = server_info['instance_id']

          # [ElastiCache]スナップショット名の確定
          final_snapshot = "fss-#{service_type}-#{instance_id}"

          # 作成時のオプションを確定
          unless server_info['create_option'].nil?
            create_option = server_info['create_option']
          else
            create_option = {}
          end
          create_option[:cache_cluster_id] = "#{instance_id}"

          # 削除時のオプションを確定
          delete_option = {}
          delete_option[:cache_cluster_id] = "#{instance_id}"
          unless create_option[:engine].nil?
            if create_option[:engine] == 'redis'
              delete_option[:final_snapshot_identifier] = "#{final_snapshot}"
            end
          end

          # 変更時の追加設定オプションを確定
          unless server_info['modify_option'].nil?
            modify_option = server_info['modify_option']
            modify_option[:cache_cluster_id] = "#{instance_id}"
          else
            modify_option = nil
          end

          # 状態確認時のオプション設定
          unless server_info['describe_option'].nil?
            describe_option = server_info['describe_option']
          else
            describe_option = {}
          end
          describe_option[:cache_cluster_id] = "#{instance_id}"

          # スナップショット削除時のオプションを確定
          delete_snapshot_option = nil;
          unless create_option[:engine].nil?
            if create_option[:engine] == 'redis'
              delete_snapshot_option = {};
              delete_snapshot_option[:snapshot_name] = "#{final_snapshot}"
            end
          end

          # ElastiCacheクライアントの初期化
          client = self.getClient(creds)

          case action
          when 'start'
            # 1. クラスタを作成
            client.create_cache_cluster(create_option)

            # 2. 作成が完了するまでの間、処理を待機
            status = ''
            until status == 'available'
              print '.'
              sleep 30

              status = self.describeClusterStatus(client, describe_option)
            end
            print '! '

            # 3. セキュリティグループ・パラメータグループを更新
            unless modify_option.nil?
              client.modify_cache_cluster(modify_option)
              sleep 30
            end

            # 4. インスタンスを再起動して更新を反映
            self.setInstance(creds, server_info, 'reboot')

            # 5. スナップショットを削除
            unless delete_snapshot_option.nil?
              client.delete_snapshot(delete_snapshot_option)
            end

            result = true
          when 'stop'
            # 1. スナップショットを作成してクラスタを削除
            client.delete_cache_cluster(delete_option)

            result = true
          when 'reboot'
            # 1. クラスタを再起動
            # TODO: ノードの動的指定
            client.reboot_cache_cluster({
              cache_cluster_id: "#{instance_id}",
              cache_node_ids_to_reboot: ["0001"],
            })

            result = true
          when 'status'
            status = ''
            # 1. クラスタの状態を取得
            status = self.describeClusterStatus(client, describe_option)

            result = status
          else
            result = "Nothing to do."
          end

          return result

        rescue => e
          raise
        end

        def describeCluster(client, describe_option)
          describe = nil
          begin
            # クラスタの状態を取得
            describe = client.describe_cache_clusters(describe_option)
          rescue
            describe = nil
          end            
          return describe
        end

        def describeClusterStatus(client, describe_option)
          status = ''
          begin
            describe = self.describeCluster(client, describe_option)
            status = describe.cache_clusters[0][:cache_cluster_status]
          rescue
            status = 'not-found'
          end
          return status
        end

      end #class self
    end #class
  end # module
end # module
