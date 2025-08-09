# Doorbell Flutter

## Home Assistant setup

Add user for the app, make the system running it a trusted system. Install kiosk mode.

URL will be something like: `http://homeassistant.localdomain/lovelace?kiosk`

```yaml
homeassistant:
  auth_providers:
    - type: trusted_networks
      trusted_networks:
        - 192.168.3.67/32
      trusted_users:
        192.168.3.67: doorbell
```