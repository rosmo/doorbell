package doorbell

import (
	"fmt"
	"log/slog"
	"time"

	dbus "github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
	gpiocdev "github.com/warthog618/go-gpiocdev"
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
	</interface>` + introspect.IntrospectDataString + `</node> `

type Doorbell struct {
	RingerGpioName string
	OpenerGpioName string
	Simulate       bool

	Ringer *gpiocdev.Line
	Opener *gpiocdev.Line

	DBusConnection *dbus.Conn
}

func NewDoorbell(opener string, ringer string, simulate bool) *Doorbell {
	return &Doorbell{
		RingerGpioName: ringer,
		OpenerGpioName: opener,
		Simulate:       simulate,
	}
}

func (bell *Doorbell) RingEvent() *dbus.Error {
	slog.Info("Door ringing!")
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

func (bell *Doorbell) SetupDBus() (err error) {
	bell.DBusConnection, err = dbus.ConnectSessionBus()
	if err != nil {
		return err
	}

	bell.DBusConnection.Export(bell, "/com/github/rosmo/Doorbell", "com.github.rosmo.Doorbell")
	bell.DBusConnection.Export(introspect.Introspectable(DBusIntro), "/com/github/rosmo/Doorbell",
		"org.freedesktop.DBus.Introspectable")

	reply, err := bell.DBusConnection.RequestName("com.github.rosmo.Doorbell", dbus.NameFlagDoNotQueue)
	if err != nil {
		return err
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		return fmt.Errorf("Name already taken in D-Bus!")
	}

	return nil
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

				bell.Ringer, err = gpiocdev.RequestLine(chip, lineInfo.Offset, gpiocdev.AsInput)
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
