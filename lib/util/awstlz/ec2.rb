require 'aws-sdk'
require 'yaml'

module Util
  module AwsTlz
    class Ec2

      class << self

        def loadConfigYaml(config_path, config_alias)
          # create configuration yaml path
          configyamlfile = config_path << '/' << config_alias << '.yml'
          # load configuration yaml file
          configcreds = YAML.load(File.read(configyamlfile))

          return configcreds
        end

        def getClient(creds)
          # Initialize AWS::EC2::Client
          client = Aws::EC2::Client.new(
            region: creds['region'],
            access_key_id: creds['access_key_id'],
            secret_access_key: creds['secret_access_key']
          ) 

          return client
        end

        def getResource(creds)
          # Initialize AWS::EC2::Client
          client = self.getClient(creds)

          # Initialise AWS::EC2::Resource
          resource = Aws::EC2::Resource.new(
            client: client
          )
          
          return resource
        end

        def getInstance(creds, instance_id)
          resource = self.getResource(creds)

          instance = resource.instance(instance_id)

          return instance
        end

        def getSecurityGroup(instance)
          # Get Current SecurityGroup
          grouplist = Array.new

          instance.security_groups.each do |security_group|
            grouplist.push(security_group.group_id)
          end
        end

        def setSecurityGroup(instance, grouplist)
          instance.modify_attribute(
            groups: grouplist
          )
        end

        def setInstance(creds, server_info, action)
          result = nil

          # 設定情報から重要項目を抽出
          service_type = server_info['service_type']
          instance_id  = server_info['instance_id']

          # EC2クライアントの初期化
          client = self.getClient(creds)

          case action
          when 'start'
            # 1. インスタンスを起動
            client.start_instances(instance_ids: [instance_id])

            result = true
          when 'stop'
            # 1. インスタンスを停止
            client.stop_instances(instance_ids: [instance_id])

            result = true
          when 'reboot'
            # 1. インスタンスを再起動
            client.reboot_instances(instance_ids: [instance_id])

            result = true
          when 'status'
            status = ''
            # 1. インスタンスの状態を取得
            status = self.describeInstanceStatus(client, {instance_ids: [instance_id]})

            result = status
          when 'ip'
            ip = ''
            # 1. インスタンスの状態を取得
            ip = self.describeInstanceIp(client, {instance_ids: [instance_id]})
            result = ip
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
            describe = client.describe_instances(describe_option)
          rescue
            describe = nil
          end

          return describe
        end

        def describeInstanceStatus(client, describe_option)
          status = ''
          begin
            # インスタンスの状態を取得
            describe = self.describeInstance(client, describe_option)
            # インスタンス名を抽出
            status = describe.reservations[0].instances[0].state.name
          rescue
            status = 'not-found'
          end

          return status
        end

        def describeInstanceIp(client, describe_option)
          instanceip = ''
          begin
            # インスタンスの状態を取得
            describe = self.describeInstance(client, describe_option)
            # IPアドレスを抽出
            instanceip = describe.reservations[0].instances[0].public_ip_address
          rescue
            instanceip = 'not-found'
          end

          return instanceip
        end

      end #class self
    end #class
  end # module
end # module
