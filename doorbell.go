package doorbell

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	dbus "github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
	gpiocdev "github.com/warthog618/go-gpiocdev"
	ini "gopkg.in/ini.v1"
)

const DBusIntro = `
<node>
	<interface name="com.github.rosmo.Doorbell">
		<method name="OpenDoor">
		</method>
		<method name="StartVideo">
		</method>
		<method name="StopVideo">
		</method>
		<signal name="BellRinging">
        </signal>
	</interface>` + introspect.IntrospectDataString + `</node> `

type Doorbell struct {
	RingerGpioName        string
	OpenerGpioName        string
	Simulate              bool
	ConfigFile            string
	HomeAssistantApiUrl   string
	HomeAssistantApiToken string
	HomeAssistantEntity   string

	Ringer *gpiocdev.Line
	Opener *gpiocdev.Line

	DBusConnection *dbus.Conn
	Http           *http.Client
}

type HomeAssistantEntity struct {
	State      string            `json:"state"`
	Attributes map[string]string `json:"attributes,omitempty"`
}

func NewDoorbell(config string, opener string, ringer string, simulate bool) *Doorbell {
	return &Doorbell{
		ConfigFile:     config,
		RingerGpioName: ringer,
		OpenerGpioName: opener,
		Simulate:       simulate,
	}
}

func (bell *Doorbell) LoadConfiguration() error {
	slog.Info("Loading configuration", slog.String("file", bell.ConfigFile))

	cfg, err := ini.Load(bell.ConfigFile)
	if err != nil {
		return fmt.Errorf("Fail to read file: %v", err)
	}

	bell.HomeAssistantApiUrl = cfg.Section("").Key("homeassistant_api_url").String()
	bell.HomeAssistantApiToken = cfg.Section("").Key("homeassistant_api_token").String()
	bell.HomeAssistantEntity = cfg.Section("").Key("homeassistant_entity_id").String()

	bell.Http = &http.Client{}
	bell.UpdateHomeAssistantEntity("off")
	return nil
}

func (bell *Doorbell) homeAssistantRequest(method string, path string, body string) (*http.Response, error) {
	url := fmt.Sprintf("%s/%s", bell.HomeAssistantApiUrl, path)

	var bodyReader io.Reader = nil
	if body != "" {
		bodyReader = strings.NewReader(body)
	}

	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", bell.HomeAssistantApiToken))
	req.Header.Add("Content-Type", "application/json")

	resp, err := bell.Http.Do(req)
	if err != nil {
		return nil, err
	}
	return resp, nil
}

func (bell *Doorbell) UpdateHomeAssistantEntity(state string) error {
	entity := HomeAssistantEntity{
		State:      state,
		Attributes: map[string]string{},
	}
	body, err := json.Marshal(entity)
	if err != nil {
		return err
	}
	_, err = bell.homeAssistantRequest("POST", fmt.Sprintf("states/%s", bell.HomeAssistantEntity), string(body))
	if err != nil {
		return err
	}
	return nil
}

func (bell *Doorbell) RingEvent() error {
	slog.Info("Door ringing!")

	err := bell.DBusConnection.Emit("/com/github/rosmo/Doorbell", "com.github.rosmo.Doorbell.BellRinging")
	if err != nil {
		return err
	}

	bell.UpdateHomeAssistantEntity("on")

	return nil
}

func (bell *Doorbell) RingEventFinished() error {
	slog.Info("Door not ringing anymore.")

	bell.UpdateHomeAssistantEntity("off")

	return nil
}

func (bell *Doorbell) OpenDoor() *dbus.Error {
	slog.Info("Opening door...")
	if !bell.Simulate {
		bell.Opener.SetValue(0)
		time.Sleep(1 * time.Second)
		bell.Opener.SetValue(1)
	} else {
		time.Sleep(1 * time.Second)
	}
	return nil
}

func (bell *Doorbell) Close() error {
	bell.DBusConnection.Close()
	return nil
}

func (bell *Doorbell) SendDesktopNotification(title string, notification string, timeout int32) error {
	obj := bell.DBusConnection.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
	call := obj.Call("org.freedesktop.Notifications.Notify",
		0,
		"Doorbell",
		uint32(0),
		"",
		title, notification,
		[]string{},
		map[string]dbus.Variant{},
		timeout)
	if call.Err != nil {
		return call.Err
	}
	return nil
}

func (bell *Doorbell) SetupDBus() (err error) {
	bell.DBusConnection, err = dbus.ConnectSessionBus()
	if err != nil {
		return err
	}

	err = bell.DBusConnection.Export(bell, "/com/github/rosmo/Doorbell", "com.github.rosmo.Doorbell")
	if err != nil {
		return err
	}
	err = bell.DBusConnection.Export(introspect.Introspectable(DBusIntro), "/com/github/rosmo/Doorbell",
		"org.freedesktop.DBus.Introspectable")
	if err != nil {
		return err
	}

	reply, err := bell.DBusConnection.RequestName("com.github.rosmo.Doorbell", dbus.NameFlagDoNotQueue)
	if err != nil {
		return err
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		return fmt.Errorf("Name already taken in D-Bus!")
	}

	bell.SendDesktopNotification("Doorbell", "Doorbell control daemon started.", 2500)

	return nil
}

func (bell *Doorbell) RingerHandler(evt gpiocdev.LineEvent) {
	if evt.Type == gpiocdev.LineEventFallingEdge {
		bell.RingEvent()

	} else {
		bell.RingEventFinished()
	}
}

func (bell *Doorbell) SetupGpio() error {
	if bell.Simulate {
		return nil
	}
	// Probe chips
	chips := gpiocdev.Chips()
	slog.Info("Probing GPIO chips...")
	for _, chip := range chips {
		slog.Info(fmt.Sprintf("Probing GPIO chip: %s", chip))
		c, err := gpiocdev.NewChip(chip)
		if err != nil {
			slog.Warn(fmt.Sprintf("Unable to probe GPIO chip %s", chip))
			continue
		}
		for line := range c.Lines() {
			lineInfo, err := c.LineInfo(line)
			if err != nil {
				slog.Warn(fmt.Sprintf("Unable to get info for line %d (chip %s)", line, chip))
				continue
			}
			if lineInfo.Name == bell.RingerGpioName {
				slog.Info(fmt.Sprintf("Ringer GPIO: %s/%d", chip, lineInfo.Offset))

				bell.Ringer, err = gpiocdev.RequestLine(chip, lineInfo.Offset, gpiocdev.AsInput, gpiocdev.WithEventHandler(bell.RingerHandler), gpiocdev.WithBothEdges)
				if err != nil {
					slog.Error("Unable to request GPIO for ringer", "error", err)
					return err
				}

			}
			if lineInfo.Name == bell.OpenerGpioName {
				slog.Info(fmt.Sprintf("Opener GPIO: %s/%d", chip, lineInfo.Offset))
				bell.Opener, err = gpiocdev.RequestLine(chip, lineInfo.Offset, gpiocdev.AsOutput(1))
				if err != nil {
					slog.Error("Unable to request GPIO for opener", "error", err)
					return err
				}
			}
		}
	}

	return nil
}
