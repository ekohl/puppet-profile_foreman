require 'spec_helper'

describe 'profile_foreman::manager' do
  let :facts do
    {
      :concat_basedir           => '/nonexistant',
      :domain                   => 'localdomain',
      :fqdn                     => 'localhost.localdomain',
      :interfaces               => 'eth0',
      :ipaddress_eth0           => '10.0.0.2',
      :netmask_eth0             => '255.255.255.0',
      :network_eth0             => '10.0.0.0',
      :operatingsystem          => 'CentOS',
      :osfamily                 => 'RedHat',
      :postgres_default_version => '8.4',
    }
  end

  context 'without parameters' do
    it 'should contain foreman' do
      should contain_class('foreman').with({
        :authentication        => true,
        :db_password           => 'UNSET',
        :repo                  => 'stable',
        :locations_enabled     => false,
        :organizations_enabled => false,
      })
    end

    it 'should set up the firewall' do
      should contain_firewall('200 allow smartproxies').with({
        :action => 'accept',
        :chain  => 'INPUT',
        :dport  => ['80','443'],
        :proto  => 'tcp',
        :source => '10.0.0.0/255.255.255.0',
        :state  => 'NEW',
      })
    end
  end

  context 'with all parameters' do
    let :params do
      {
        :locations_enabled     => true,
        :organizations_enabled => true,
        :api_firewall          => {
          '210 extra' => {'source' => '192.168.2.0/24'},
        },
      }
    end

    it 'should contain foreman' do
      should contain_class('foreman').with({
        :authentication        => true,
        :db_password           => 'UNSET',
        :repo                  => 'stable',
        :locations_enabled     => true,
        :organizations_enabled => true,
      })
    end

    it 'should set up the firewall' do
      should contain_firewall('200 allow smartproxies').with({
        :action => 'accept',
        :chain  => 'INPUT',
        :dport  => ['80','443'],
        :proto  => 'tcp',
        :source => '10.0.0.0/255.255.255.0',
        :state  => 'NEW',
      })

      should contain_firewall('210 extra').with({
        :action => 'accept',
        :chain  => 'INPUT',
        :dport  => '443',
        :proto  => 'tcp',
        :source => '192.168.2.0/24',
        :state  => 'NEW',
      })
    end
  end
end
