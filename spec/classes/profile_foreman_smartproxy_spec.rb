require 'spec_helper'

describe 'profile_foreman::smartproxy' do
  let :facts do
    {
      :fqdn                   => 'localhost',
      :operatingsystem        => 'CentOS',
      :operatingsystemrelease => '6',
      :osfamily               => 'RedHat',
    }
  end

  let :params do
    {
      :ipaddr      => '127.0.0.1',
      :netmask     => '255.0.0.0',
      :gateway     => '',
      :foreman_url => 'https://localhost/',
    }
  end

  describe 'with minimal parameters' do
    it 'should include puppet without puppetdb' do
      should contain_class('puppet').with({
        :show_diff                   => true,
        :server                      => true,
        :server_ca                   => false,
        :server_git_repo             => true,
        :server_foreman_url          => params[:foreman_url],
        :server_storeconfigs_backend => '',
        :server_external_nodes       => '/etc/puppet/node.rb',
        :server_passenger_max_pool   => 4,
        :server_enc_api              => 'v1',
        :server_report_api           => 'v1',
      })

      should_not contain_class('puppetdb::master::config')
    end

    it 'should configure foreman-proxy' do
      should contain_class('foreman_proxy').with({
        :repo                => 'stable',
        :register_in_foreman => true,
        :registered_name     => facts[:fqdn],
        :foreman_base_url    => params[:foreman_url],
        :puppetrun           => true,
        :puppetca            => false,
        :dhcp                => true,
        :dhcp_managed        => true,
        :dhcp_gateway        => params[:gateway],
        :dhcp_range          => false,
        :dhcp_nameservers    => 'default',
        :dhcp_interface      => 'eth1',
        :tftp                => true,
        :tftp_servername     => params[:ipaddr],
        :dns                 => false,
        :dns_interface       => 'eth1',
        :dns_reverse         => '',
      })
    end

    it 'should configure the interface' do
      should contain_managed_interface('eth1').with({
        :ipaddr  => params[:ipaddr],
        :netmask => params[:netmask],
        :gateway => params[:gateway],
      })
    end

    # TODO: firewall rules are virtual, so can't test
  end

  describe 'with filter env' do
    let :params do
      {
        :ipaddr      => '127.0.0.1',
        :netmask     => '255.0.0.0',
        :gateway     => '',
        :foreman_url => 'https://localhost/',
        :filter_env  => true,
      }
    end

    it 'should add --no-environment' do
      should contain_class('puppet').with({
        :server_external_nodes => '/etc/puppet/node.rb --no-environment'
      })
    end
  end

  describe 'without puppet' do
    let :params do
      {
        :ipaddr      => '127.0.0.1',
        :netmask     => '255.0.0.0',
        :gateway     => '',
        :foreman_url => 'https://localhost/',
        :puppet      => false,
      }
    end

    it 'should not contain puppet' do
      should_not contain_class('puppet')
      should_not contain_class('puppetdb::master::config')
    end

    it 'should disable the puppet feature on foreman_proxy' do
      should contain_class('foreman_proxy').with({
        :puppetrun => false,
      })
    end
  end

  describe 'with puppetdb' do
    let :params do
      {
        :ipaddr          => '127.0.0.1',
        :netmask         => '255.0.0.0',
        :gateway         => '',
        :foreman_url     => 'https://localhost/',
        :puppetdb_server => 'puppetdb.example.org',
      }
    end

    it 'should set up puppet' do
      should_not contain_class('puppet').with({
        :storeconfigs_backend => 'puppetdb'
      })
    end

    it 'should include puppetdb master config' do
      should contain_class('puppetdb::master::config').with({
        :puppetdb_server => params[:puppetdb_server],
        :require         => 'Class[Puppet]',
      })
    end
  end

  describe 'proxy registration' do
    context 'on a manager' do
      let :facts do
        {
          :fqdn                   => 'foreman.example.org',
          :operatingsystem        => 'CentOS',
          :operatingsystemrelease => '6',
          :osfamily               => 'RedHat',
        }
      end

      it 'should register itself with foreman' do
        should contain_class('foreman_proxy').with({
          :register_in_foreman => true,
          :registered_name     => 'foreman',
          :foreman_base_url    => 'https://localhost/',
        })
      end
    end

    context 'on a smartproxy' do
      let :facts do
        {
          :fqdn                   => 'smartproxy.development.example.org',
          :operatingsystem        => 'CentOS',
          :operatingsystemrelease => '6',
          :osfamily               => 'RedHat',
        }
      end

      it 'should register itself with development' do
        should contain_class('foreman_proxy').with({
          :register_in_foreman => true,
          :registered_name     => 'development',
          :foreman_base_url    => 'https://localhost/',
        })
      end
    end

    context 'overridden' do
      let :params do
        {
          :ipaddr          => '127.0.0.1',
          :netmask         => '255.0.0.0',
          :gateway         => '',
          :foreman_url     => 'https://localhost/',
          :registered_name => 'my_proxy',
        }
      end

      it 'should register itself with my_proxy' do
        should contain_class('foreman_proxy').with({
          :register_in_foreman => true,
          :registered_name     => 'my_proxy',
          :foreman_base_url    => 'https://localhost/',
        })
      end
    end
  end
end
