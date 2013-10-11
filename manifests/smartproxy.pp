class profile_foreman::smartproxy(
  $ipaddr,
  $netmask,
  $gateway,
  $foreman_url,
  $dhcp=true,
  $dhcp_managed=true,
  $dhcp_nameservers='default',
  $dhcp_range=false,
  $tftp=true,
  $dns=false,
  $dns_reverse='',
  $puppet=true,
  $puppetca=false,
  $interface='eth1',
  $puppetdb_server=false,
  $filter_env=false,
  $passenger_max_pool=4,
  $registered_name=undef,
) {
  validate_bool($dhcp, $dhcp_managed, $tftp, $dns, $puppet, $puppetca)

  if $puppet or $puppetca {
    if $puppet {
      include puppet::params

      if $filter_env {
        $external_nodes = "${::puppet::params::server_external_nodes} --no-environment"
      } else {
        $external_nodes = $::puppet::params::server_external_nodes
      }

      $git_repo = true

      if $puppetdb_server {
        $storeconfigs_backend = 'puppetdb'
      } else {
        $storeconfigs_backend = ''
      }
    } else {
      $external_nodes = ''
      $git_repo = false
      $storeconfigs_backend = ''
    }

    class {'puppet':
      show_diff                   => true,
      server                      => $puppet,
      server_ca                   => $puppetca,
      server_git_repo             => $git_repo,
      server_foreman_url          => $foreman_url,
      server_storeconfigs_backend => $storeconfigs_backend,
      server_external_nodes       => $external_nodes,
      server_passenger_max_pool   => $passenger_max_pool,
      server_enc_api              => 'v1',
      server_report_api           => 'v1',
    }
  }

  if $puppet and $puppetdb_server {
    validate_string($puppetdb_server)
    class {'puppetdb::master::config':
      puppetdb_server => $puppetdb_server,
      require         => Class['puppet'],
    }
  }

  if $registered_name {
    $proxy_name = $registered_name
  } else {
    $proxy_name = regsubst($::fqdn, '^(smartproxy\.)?(.+?)(\.example\.org)?$', '\2')
  }

  class {'foreman_proxy':
    repo                => 'stable',

    # Registration
    register_in_foreman => true,
    registered_name     => $proxy_name,
    foreman_base_url    => $foreman_url,

    # Puppet
    puppetrun           => $puppet,
    puppetca            => $puppetca,

    # DHCP
    dhcp                => $dhcp,
    dhcp_managed        => $dhcp_managed,
    dhcp_gateway        => $gateway,
    dhcp_range          => $dhcp_range,
    dhcp_nameservers    => $dhcp_nameservers,
    dhcp_interface      => $interface,

    # TFTP
    tftp                => $tftp,
    tftp_servername     => $ipaddr,

    # DNS
    dns                 => $dns,
    dns_interface       => $interface,
    dns_reverse         => $dns_reverse,
  }

  managed_interface { $interface:
    ipaddr  => $ipaddr,
    netmask => $netmask,
    gateway => $gateway,
  }

  Firewall <<| tag == 'smartproxies' |>>

  # Determine the local network
  $local_net = inline_template("<%= scope.lookupvar('network_${interface}') %>/<%= scope.lookupvar('netmask_${interface}') %>")

  # Only apply the firewall if the interface is up
  if $local_net != '/' {

    if $puppet or $puppetca {
      @firewall { '200 Allow Local Puppet':
        chain  => 'INPUT',
        state  => 'NEW',
        source => $local_net,
        proto  => 'tcp',
        dport  => '8140',
        action => 'accept',
      }

      if $puppet {
        @@firewall { "200 Allow puppetca clients from ${::fqdn}":
          action => 'accept',
          chain  => 'INPUT',
          source => $local_net,
          dport  => '8140',
          proto  => 'tcp',
          state  => 'NEW',
          tag    => 'foreman managers',
        }
      }
    }

    if $dhcp {
      @firewall { '200 Allow DHCP':
        chain  => 'INPUT',
        source => $local_net,
        proto  => 'udp',
        dport  => ['67','68'],
        action => 'accept',
      }

      @@firewall { "200 Allow kickstart clients from ${::fqdn}":
        action => 'accept',
        chain  => 'INPUT',
        source => $local_net,
        dport  => '80',
        proto  => 'tcp',
        state  => 'NEW',
        tag    => 'foreman managers',
      }
    }

    if $tftp {
      @firewall { '200 Allow TFTP':
        chain  => 'INPUT',
        source => $local_net,
        proto  => 'udp',
        dport  => '69',
        action => 'accept',
      }
    }

    if $dns {
      @firewall { '200 Allow DNS new':
        chain  => 'INPUT',
        state  => 'NEW',
        proto  => 'tcp',
        dport  => '53',
        action => 'accept',
      }

      @firewall { '200 Allow DNS':
        chain  => 'INPUT',
        proto  => 'udp',
        dport  => '53',
        action => 'accept',
      }
    }
  }
}
