# ns8-zabbix

This is the Zabbix monitoring system for [NethServer 8](https://github.com/NethServer/ns8-core).

## Install

Install via Software Center by adding my [repository](https://repo.mrmarkuz.com)

Install via CLI:

    add-module ghcr.io/nethserver/zabbix:latest 

The output of the command will return the instance name.
Output example:

    {"module_id": "zabbix1", "image_name": "zabbix", "image_url": "ghcr.io/nethserver/zabbix:latest"}

## Configuration

The FQDN needs to be configured.

The servername is the text under the Zabbix logo.

The time zone is the PHP timezone format like "Europe/Vienna".

## Uninstall

To uninstall the instance via CLI:

    remove-module --no-preserve zabbix1
