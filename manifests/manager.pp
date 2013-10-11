# Class: profile_foreman::manager
#
# === Parameters:
#
# $locations_enabled::      Whether to enable locations
#                           type:boolean
#
# $organizations_enabled::  Whether to enable organizations
#                           type:boolean
#
# $repo::                   The repository to use
#
# $api_firewall::           Extra firewall rules for API access (port 443).
#                           type:hash
#
class profile_foreman::manager(
  $locations_enabled = false,
  $organizations_enabled = false,
  $repo = 'stable',
  $api_firewall = {},
) {
  validate_bool($locations_enabled, $organizations_enabled)
  validate_string($repo)
  validate_hash($api_firewall)

  class {'foreman':
    authentication        => true,
    db_password           => 'UNSET',
    repo                  => $repo,
    locations_enabled     => $locations_enabled,
    organizations_enabled => $organizations_enabled,
  }

  # All smartproxies are in our local network and should be allowed
  firewall {'200 allow smartproxies':
    action => 'accept',
    chain  => 'INPUT',
    dport  => ['80','443'],
    proto  => 'tcp',
    source => "${::network_eth0}/${::netmask_eth0}",
    state  => 'NEW',
  }

  # Allow API access
  $api_firewall_defaults = {
    action => 'accept',
    chain  => 'INPUT',
    dport  => '443',
    proto  => 'tcp',
    state  => 'NEW',
  }

  create_resources('firewall', $api_firewall, $api_firewall_defaults)

  # Export a firewall rule to smartproxies
  @@firewall { "200 Allow Foreman API for ${::fqdn}":
    chain  => 'INPUT',
    source => $ipaddress_eth0,
    proto  => 'tcp',
    dport  => '8443',
    action => 'accept',
    tag    => 'smartproxies',
  }

  # Collect all firewall rules for managers
  Firewall <<| tag == 'foreman managers' |>>
}
