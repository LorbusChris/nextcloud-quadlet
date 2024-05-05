# Nextcloud Quadlet

Run containerized Nextcloud as systemd services with Podman 5.

## Setup

Clone this repo and enter the directory.
Next, create an `inventory.yaml` with the following variables:

```yaml
all:
  hosts:
    #127.0.0.1:
    #  ansible_connection: local
    #  ansible_user: myuser
    192.168.100.42:
      ansible_connection: ssh
      ansible_user: myuser
      ansible_ssh_private_key_file: ~/.ssh/my.key
  vars:
    nc_admin_password: "MYSUPERSECRETNCADMINPW"
    nc_trusted_domains: "cloud.example.com"
    nc_trusted_proxies: ""
    nc_default_language: "de"
    nc_default_phone_region: "DE"
    nc_default_locale: "de_DE"
    nc_default_timezone: "Europe/Berlin"
    ansible_become_password: "MYSUDOPW"

```

Note: The Ansible Playbook expects the TLS certs for use with Nextcloud's Envoy proxy to already
be present at `~/storage/nextcloud/certs/certificate.{key,pem}` on the target machine.

Run the playbook with `ansible-playbook playbook.yml`.

Go to `cloud.example.com:8000`.
