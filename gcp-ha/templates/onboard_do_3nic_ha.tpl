{
  "schemaVersion": "1.0.0",
  "class": "Device",
  "async": true,
  "label": "Onboard BIG-IP",
  "Common": {
    "class": "Tenant",
    "mySystem": {
      "class": "System",
      "hostname": "${hostname}.local"
    },
    "myDns": {
      "class": "DNS",
      "nameServers": [
        ${name_servers}
      ],
      "search": [
        "f5.com"
      ]
    },
    "myNtp": {
      "class": "NTP",
      "servers": [
        ${ntp_servers}
      ],
      "timezone": "UTC"
    },
    "${vlan-name1}": {
      "class": "VLAN",
      "tag": 4093,
      "mtu": 1460,
      "interfaces": [
        {
          "name": "1.0",
          "tagged": false
        }
      ],
      "cmpHash": "dst-ip"
    },
    "${vlan-name1}-self": {
      "class": "SelfIp",
      "address": "${self-ip1}/32",
      "vlan": "${vlan-name1}",
      "allowService": "default",
      "trafficGroup": "traffic-group-local-only"
    },
    "external_gw_rt": {
      "class": "Route",
      "target": "${vlan-name1}",
      "network":  "${gateway}/32",
      "mtu": 1460
    },
    "external_route": {
      "class": "Route",
      "gw": "${gateway}",
      "network":  "${ext_cidr_range}",
      "mtu": 1460
    },
    "${vlan-name2}": {
      "class": "VLAN",
      "tag": 4094,
      "mtu": 1460,
      "interfaces": [
        {
          "name": "1.2",
          "tagged": false
        }
      ],
      "cmpHash": "dst-ip"
    },
    "${vlan-name2}-self": {
      "class": "SelfIp",
      "address": "${self-ip2}/32",
      "vlan": "${vlan-name2}",
      "allowService": "default",
      "trafficGroup": "traffic-group-local-only"
    },
    "configsync": {
        "class": "ConfigSync",
        "configsyncIp": "/Common/${vlan-name1}-self/address"
    },    
    "failoverGroup": {
        "class": "DeviceGroup",
        "type": "sync-failover",
        "members": [
            "${primary}",
            "${secondary}"
        ],
        "owner": "/Common/failoverGroup/members/0",
        "autoSync": true,
        "saveOnAutoSync": true,
        "networkFailover": true,
        "fullLoadOnSync": false,
        "asmSync": false
    },
    "trust": {
        "class": "DeviceTrust",
        "localUsername": "admin",
        "localPassword": "${password}",
        "remoteHost": "/Common/failoverGroup/members/0",
        "remoteUsername": "admin",
        "remotePassword": "${password}"
    }     
  }
}
