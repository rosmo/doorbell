package doorbell

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	chi "github.com/go-chi/chi/v5"
	middleware "github.com/go-chi/chi/v5/middleware"
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
	ApiToken              string
	ApiUrl                string

	Ringing bool

	Ringer *gpiocdev.Line
	Opener *gpiocdev.Line

	LastRing                      time.Time
	RingDoneTimer                 *time.Timer
	HomeAssistantUpdateTicker     *time.Ticker
	HomeAssistantUpdateTickerDone chan bool

	DBusConnection *dbus.Conn
	Http           *http.Client
	HttpServer     *http.Server
}

type HomeAssistantEntity struct {
	State      string            `json:"state"`
	Attributes map[string]string `json:"attributes,omitempty"`
}

type HomeAssistantRingEvent struct {
	EntityId       string `json:"entity_id"`
	CameraImageUrl string `json:"camera_image_url,omitempty"`
}

type ConfigRequest struct {
	SirenEntityId string `json:"siren_entity_id"`
}

func NewDoorbell(config string, opener string, ringer string, simulate bool) *Doorbell {
	return &Doorbell{
		ConfigFile:     config,
		RingerGpioName: ringer,
		OpenerGpioName: opener,
		Simulate:       simulate,
		LastRing:       time.Now(),
	}
}

func (bell *Doorbell) StartHomeAssistantReporting() error {
	bell.HomeAssistantUpdateTicker = time.NewTicker(10 * time.Second)
	bell.HomeAssistantUpdateTickerDone = make(chan bool)
	go func() {
		for {
			select {
			case <-bell.HomeAssistantUpdateTickerDone:
				slog.Info(fmt.Sprintf("Home assistant reporter done"))
				return
			case <-bell.HomeAssistantUpdateTicker.C:
				slog.Info("Updating Home Assistant with status...")
				if bell.Ringing {
					bell.UpdateHomeAssistantEntity("on")
				} else {
					bell.UpdateHomeAssistantEntity("off")
				}
			}
		}
	}()
	return nil
}

func (bell *Doorbell) LoadConfiguration() error {
	slog.Info("Loading configuration", slog.String("file", bell.ConfigFile))

	cfg, err := ini.Load(bell.ConfigFile)
	if err != nil {
		return fmt.Errorf("Fail to read file: %v", err)
	}

	bell.HomeAssistantApiUrl = cfg.Section("").Key("homeassistant_api_url").String()
	bell.HomeAssistantApiToken = cfg.Section("").Key("homeassistant_api_token").String()
	bell.ApiToken = cfg.Section("").Key("api_token").String()
	bell.ApiUrl = cfg.Section("").Key("api_url").String()

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

	slog.Info(fmt.Sprintf("Calling %s %s...", method, url))
	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", bell.HomeAssistantApiToken))
	req.Header.Add("Content-Type", "application/json")

	retries := 0
	for {
		resp, err := bell.Http.Do(req)
		if err != nil {
			return nil, err
		}
		slog.Info("Home Assistant response", "statuscode", resp.StatusCode)
		if resp.StatusCode < 200 || resp.StatusCode > 399 {
			time.Sleep(1 * time.Second)
			retries++
			if retries > 5 {
				responseBody, err := ioutil.ReadAll(resp.Body)
				if err != nil {
					return nil, err
				}
				slog.Error("Home Assistant returned error", "body", string(responseBody))
				return nil, err
			}
		} else {
			return resp, nil
		}
	}
}

func (bell *Doorbell) UpdateHomeAssistantEntity(state string) error {
	if bell.HomeAssistantEntity == "" {
		return nil
	}

	if state == "on" {
		event := HomeAssistantRingEvent{
			EntityId:       bell.HomeAssistantEntity,
			CameraImageUrl: fmt.Sprintf("%s/cameraimage", bell.ApiUrl),
		}
		eventBody, err := json.Marshal(event)
		if err != nil {
			return err
		}
		_, err = bell.homeAssistantRequest("POST", fmt.Sprintf("events/doorbell_ringing"), string(eventBody))
		if err != nil {
			return err
		}
	}

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
	now := time.Now()
	sinceLastRing := now.Sub(bell.LastRing)
	if sinceLastRing > (5 * time.Second) {
		slog.Info("Door ringing!")
		bell.Ringing = true

		err := bell.DBusConnection.Emit("/com/github/rosmo/Doorbell", "com.github.rosmo.Doorbell.BellRinging")
		if err != nil {
			return err
		}

		bell.UpdateHomeAssistantEntity("on")

		// Schedule a timer to stop ringing after 5 seconds
		if bell.RingDoneTimer == nil {
			bell.RingDoneTimer = time.NewTimer(5 * time.Second)
			go func() {
				<-bell.RingDoneTimer.C
				bell.RingDoneTimer = nil

				err := bell.RingEventFinished()
				if err != nil {
					slog.Error("An error was encountered processing ring finished timer!", "error", err)
				}
			}()
		}
		bell.LastRing = now
	} else {
		slog.Warn("Supressed superfluous ringing start event...")
	}
	return nil
}

func (bell *Doorbell) RingEventFinished() error {
	now := time.Now()
	sinceLastRing := now.Sub(bell.LastRing)
	if sinceLastRing > (2 * time.Second) {
		if bell.RingDoneTimer != nil {
			slog.Info("Ringing done time already running, allowing it to finish the task.")
			return nil
		}
		slog.Info("Door not ringing anymore.")
		bell.Ringing = false

		bell.UpdateHomeAssistantEntity("off")
	} else {
		slog.Warn("Supressed superfluous ringing stop event...")
	}
	return nil
}

func (bell *Doorbell) OpenDoor() *dbus.Error {
	slog.Info("Opening door...")
	if !bell.Simulate {
		bell.Opener.SetValue(0)
		time.Sleep(2 * time.Second)
		bell.Opener.SetValue(1)
	} else {
		time.Sleep(2 * time.Second)
	}
	return nil
}

func (bell *Doorbell) DBusClose() error {
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
	slog.Info("Registering doorbell on D-Bus...")
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

	/*
		go func() {
			slog.Info("Sending startup notification...")
			bell.SendDesktopNotification("Doorbell", "Doorbell control daemon started.", 2500)
			slog.Info("Notification sent!")
		}()
	*/

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

AllProbed:
	for _, chip := range chips {
		slog.Info(fmt.Sprintf("Probing GPIO chip: %s", chip))
		c, err := gpiocdev.NewChip(chip)
		if err != nil {
			slog.Warn(fmt.Sprintf("Unable to probe GPIO chip %s", chip))
			continue
		}
		for line := range c.Lines() {
			if bell.Ringer != nil && bell.Opener != nil {
				break AllProbed
			}
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

func (bell *Doorbell) StartHttpServer(port int) error {
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(bell.TokenValidatorMiddleware)
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Doorbell API"))
	})
	r.Get("/cameraimage", func(w http.ResponseWriter, r *http.Request) {
		image, err := os.ReadFile("testimage.jpg")
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to get camera image: %v", err), 500)
			return
		}
		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(image)))
		w.Write(image)
	})
	r.Post("/configure", func(w http.ResponseWriter, r *http.Request) {
		decoder := json.NewDecoder(r.Body)
		var t ConfigRequest
		err := decoder.Decode(&t)
		if err == nil {
			slog.Info(fmt.Sprintf("Updating siren entity to: %s", t.SirenEntityId))
			bell.HomeAssistantEntity = t.SirenEntityId
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte("{ \"ok\": true }"))
		} else {
			http.Error(w, fmt.Sprintf("Failed to decode configuration request: %v", err), 400)
		}
	})
	r.Post("/opendoor", func(w http.ResponseWriter, r *http.Request) {
		err := bell.OpenDoor()
		if err == nil {
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte("{ \"ok\": true }"))
		} else {
			http.Error(w, fmt.Sprintf("Failed to open door: %v", err), 500)
		}
	})
	bell.HttpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: r,
	}
	go func() {
		if err := bell.HttpServer.ListenAndServe(); err != http.ErrServerClosed {
			slog.Error("Error starting web server", "error", err)
		}
	}()
	return nil
}

func (bell *Doorbell) TokenValidatorMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" && r.URL.Path != "/cameraimage" {
			authorization := r.Header.Get("Authorization")
			if authorization == "" {
				http.Error(rw, "Forbidden, check your bearer token", 403)
				return
			}

			tokenSplit := strings.SplitN(authorization, " ", 2)
			if len(tokenSplit) < 2 || tokenSplit[1] != bell.ApiToken {
				http.Error(rw, "Forbidden, check your bearer token", 403)
				return
			}
		}
		next.ServeHTTP(rw, r)
	})
}

func (bell *Doorbell) StopHttpServer() error {
	if err := bell.HttpServer.Shutdown(context.TODO()); err != nil {
		return err
	}
	return nil
}
