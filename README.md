# ns8-zabbix

This is the Zabbix monitoring system for [NethServer 8](https://github.com/NethServer/ns8-core).

## Install

Install via Software Center by adding my repo as explained [here](https://repo.mrmarkuz.com)

Install via CLI:

    add-module ghcr.io/nethserver/zabbix:latest 

The output of the command will return the instance name.
Output example:

    {"module_id": "zabbix1", "image_name": "zabbix", "image_url": "ghcr.io/nethserver/zabbix:latest"}

## Import of NS7 Zabbix database (optional)

This is only possible before the web UI configuration of Zabbix.

Force a backup on NS7 by running `/etc/e-smith/events/actions/nethserver-zabbix-backup`
Copy `/var/lib/nethserver/zabbix/backup/zabbix.sql` from NS7 to the `/root` on NS8

Login to NS8 as root and run following commands. Define your zabbix instance in the first command, in this example it's zabbix1.

```
export instance=zabbix1 # Define the Zabbix instance name you want to import
sed -i -e 's/OWNER TO zabbix/OWNER TO postgres/g' zabbix.sql # Change user zabbix to postgres for NS8
runagent -m $instance mkdir restore # Create restore directory
cp zabbix.sql /home/$instance/.config/state/restore/ # Copy zabbix.sql to the created restore directory
chown $instance:$instance /home/$instance/.config/state/restore/zabbix.sql # Set right owner for zabbix.sql
runagent -m $instance # Go into the instance environment
# Run podman to import the DB
podman run \
    --cgroups=no-conmon \
    --replace -d --name postgresql-app \
    --volume postgres-data:/var/lib/postgresql/data:Z \
    --volume ./restore/:/docker-entrypoint-initdb.d/:Z \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=Nethesis,1234 \
    --env POSTGRES_DB=zabbix \
    --env TZ=UTC \
    ${POSTGRES_IMAGE}
```

Check logs if import is finished, following entry shows the end of the import:

`LOG: received fast shutdown request`

Execute following commands to tidy up:

```
podman stop postgresql-app # stop container
rm restore/zabbix.sql # remove zabbix.sql
exit # Exit zabbix environment
```

Now you can go on to module configuration in the web UI...

## Configuration

Zabbix opens port 10051, so there can be just one instance per node.

The FQDN, the servername and the time zone needs to be configured.

The servername is shown under the Zabbix logo and in the page title (shown in browser tab).

The time zone is the PHP timezone format like "Europe/Vienna".

## Login

The default username is Admin and the password is zabbix. Please change the password as soon as possible.

## Uninstall

To uninstall the instance via CLI:

    remove-module --no-preserve zabbix1
