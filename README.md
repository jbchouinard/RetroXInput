# JoyEmu

The JoyEmu.ahk script maps standard buttons and joysticks from a xinput controller
to keyboard inputs

It features advanced joystick emulation for D-Pad based classic consoles like the SNES.
Typically, when a joystick is mapped to D-Pad inputs in an emulator,
the input is all-or-nothing. Pushing the stick halfway maps to a pressed D-Pad
and causes full speed movement.

JoyEmu uses something like pulse-width modulation to create analog-like movement
by manipulating D-Pad inputs. For example, if the joystick is pushed halfway to the right,
JoyEmu sends D-Pad Right inputs every other frame, causing movement at half speed.

It works very well in games that have physics with inertia, like Super Mario World.
The inertia smooths out movement.

It works less well in games with no inertia, like Gradius III, where it produces
jittery movement.

Extra buttons on the controller can be configured for Turbo or Toggle.
Xbox-style triggers can be configured for variable-rate Turbo
(the more it's pressed, the faster it repeats).

For Super Mario World, you could set up a Toggle for the run button and leave it
always on, and use the analog stick to walk/run.

## Requirements

AutoHotkey v1.1: https://www.autohotkey.com/

A XInput controller, such as Xbox controllers.