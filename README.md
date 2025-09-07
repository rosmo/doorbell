
# Home Assistant "dumb door phone" integration

Hardware:
- Raspberry Pi Zero or Radxa Zero or equivalent
  - With suitable touch screen
- 3.3V relay
- 24V optoisolator module
- USB composite video converter

Software:
- Daemon written in Golang, handles GPIOs, small API and Home Assistant comms
- Custom integration for Home Assistant
- Flutter Native UI for Linux integrating door controls, embedded browser for 
  Home Assistant and music player (why not)
- DietPi for operating system

## Testing DBus

```sh
busctl --user call com.github.rosmo.Doorbell /com/github/rosmo/Doorbell com.github.rosmo.Doorbell OpenDoor
```

## API

Two endpoints:

- `POST /opendoor` - triggers the relay
- `POST /configure` - updates `siren_entity_id` from Home Assistant

## Home Assistant

### Configuration

```yaml
doorbell:
  deviceid: doorbell
  name: "Outer door"
  host: 192.168.1.123
  port: 80
  token: test123
```

### Sample automation

```yaml
alias: Doorbell testing
description: ""
triggers:
  - trigger: state
    entity_id:
      - siren.outer_door_ring
    from: "on"
conditions: []
actions:
  - action: notify.mobile_app_tanelis_iphone
    data:
      message: Doorbell is ringing!
      data:
        push:
          sound:
            name: default
            critical: 1
            volume: 0
            priority: high
            ttl: 0
        actions:
          - action: open_door
            title: Open door
            destructive: true
    metadata: {}
  - wait_for_trigger:
      - trigger: event
        event_type: mobile_app_notification_action
        event_data:
          action: open_door
  - choose:
      - conditions:
          - condition: template
            value_template: "{{ wait.trigger.event.data.action == 'open_door' }}"
        sequence:
          - action: button.press
            target:
              entity_id: button.outer_door_open_2
mode: parallel
```