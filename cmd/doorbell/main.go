package main

import (
	"flag"
	"fmt"
	"log/slog"
	"os"
	"time"

	"golang.org/x/term"

	"github.com/rosmo/doorbell"
)

func main() {
	openerGpioPtr := flag.String("opener-gpio", "PIN_7", "GPIO for door opener relay")
	ringerGpioPtr := flag.String("ringer-gpio", "PIN_11", "GPIO for door ringer detector")
	simulatePtr := flag.Bool("simulate", false, "Instead of opening GPIOs, just simulate")
	configFilePtr := flag.String("config", "", "Configuration file in .INI format")
	flag.Parse()

	bell := doorbell.NewDoorbell(*configFilePtr, *openerGpioPtr, *ringerGpioPtr, *simulatePtr)

	err := bell.LoadConfiguration()
	if err != nil {
		panic(err)
	}

	err = bell.SetupGpio()
	if err != nil {
		panic(err)
	}

	err = bell.SetupDBus()
	if err != nil {
		panic(err)
	}
	slog.Info("Listening on D-Bus...")

	if *simulatePtr {
		slog.Info("Simulation mode active, press O to open door, R to simulate ring, ^C to terminate")
		oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
		if err != nil {
			panic(err)
		}
		defer term.Restore(int(os.Stdin.Fd()), oldState)

		for {
			b := make([]byte, 1)
			_, err = os.Stdin.Read(b)
			if err != nil {
				panic(err)
			}
			if b[0] == 0x03 {
				break
			}
			if b[0] == 'r' || b[0] == 'R' {
				err = bell.RingEvent()
				if err != nil {
					panic(err)
				}
				time.Sleep(5 * time.Second)
				err = bell.RingEventFinished()
				if err != nil {
					panic(err)
				}
			}
			if b[0] == 'o' || b[0] == 'O' {
				err = bell.OpenDoor()
				if err != nil {
					panic(err)
				}
			}
			fmt.Printf("\r\n")
		}
	} else {
		select {}
	}
}
