# RetroXInput

RetroXInput is a AutoHotkey script that adds extra features
to XInput controllers for emulated retro games (SNES, Genesis, etc.).

Specifically:
- simulated analog movement
- turbo mode (aka autofire)
- variable rate turbo on analog triggers
- toggle mode
- keyboard mapping


## Requirements
- Windows
- AutoHotkey v1.1 (Current Version): https://www.autohotkey.com/
- xinput1_3.dll: probably already installed, if not: http://www.microsoft.com/en-us/download/confirmation.aspx?id=8109


### Supported Controllers

Only XInput controllers (e.g. Xbox One) are supported, but many other controllers
can be mapped to XInput:
- Sony DualShock 3/4 and DualSense 5 using [DS4Windows](https://github.com/Ryochan7/DS4Windows)
- Various DirectInput controllers using [x360ce](https://www.x360ce.com/)

I've tested with:
- Xbox 360 wired controller
- Xbox One wireless controller
- DualShock 4 controller with DS4Windows
- Wii U Pro controller with Mayflash adapter in XInput mode


## Installation & Usage

Put RetroXInput.ahk, RetroXInput.ini and the Lib folder somewhere.

Run RetroXInput.ahk with AutoHotkeys.


## Features

### Keyboard Mapping

Map gamepad inputs to keyboard keys.

### Simulated Analog Movement

Finally, an answer to the question no one asked: what if the SNES had
analog controls?

Uusally emulators can be configured to map a joystick to d-pad inputs,
but it's purely on/off.

RetroXInput tries to simulate analog movement in d-pad only games,
by mashing the d-pad very quickly and precisely, at a variable rate
depending on the joystick position (yes, this is cheating).

It works very well in games that have physics with inertia, like
Super Mario World. The inertia smooths out the jittery d-pad inputs.

It works less well in games with no inertia, like Gradius III, where
the jitter is pretty apparent.

### Turbo Mode (Autofire)

Hold a button and the computer will mash it for you 20 times per second
(this is also cheating).

### Variable Rate Turbo Mode (Autofire)

If you configure turbo on an analog triggers (LR, LT),
the rate of fire will vary based on the trigger input.

### Toggle Mode

Pressing the button toggles it on or off.


## Configuration

See RetroXInput.ini for configuration options.

Not all emulators support using combinations of keyboard and
gamepad inputs for the same controller port, so the most compatible
setup is to map every button to keyboard keys, and then configure
the emulator to use keyboard only.

Annoyingly, some emulators like Mesen-S uses XInput controlllers
automatically even when keyboard input is configured.
