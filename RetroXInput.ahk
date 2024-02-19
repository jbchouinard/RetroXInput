; RetroXInput Version 1.0.0
; Copyright 2022 Jerome Boisvert-Chouinard
#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
XInput_Init()

configFile := A_ScriptDir "\RetroXInput.ini"
OutputDebug % "Loading config from " configFile

; Set later by ReadConfig* functions
allButtons := []
leftJoystick := 0
rightJoystick := 0
leftTrigger := 0
rightTrigger := 0


KeyNameMap := {Start: "Start"
	,Back: "Back"
	,Select: "Back"
	,Up: "Up"
	,DU: "Up"
	,Down: "Down"
	,DD: "Down"
	,Left: "Left"
	,DL: "Left"
	,Right: "Right"
	,DR: "Right"
	,A: "A"
	,B: "B"
	,X: "X"
	,Y: "Y"
	,LB: "LB"
	,RB: "RB"
	,LT: "LT"
	,RT: "RT"
	,LSB: "LSB"
	,RSB: "RSB"
	,NinX: "Y"
	,NinY: "X"
	,NinA: "B"
	,NinB: "A"
	,L: "LB"
	,R: "RB"
	,ZL: "LT"
	,ZR: "RT"
	,LeftStick: "LSB"
	,RightStick: "RSB"
	,Cross: "A"
	,Circle: "B"
	,Square: "X"
	,Triangle: "Y"
	,L1: "LB"
	,R1: "RB"
	,L2: "LT"
	,R2: "RT"
	,L3: "LSB"
	,R3: "RSB"}

Bitmask := {Start: XINPUT_GAMEPAD_START
	,Back: XINPUT_GAMEPAD_BACK
	,A: XINPUT_GAMEPAD_A
	,B: XINPUT_GAMEPAD_B
	,X: XINPUT_GAMEPAD_X
	,Y: XINPUT_GAMEPAD_Y
	,LB: XINPUT_GAMEPAD_LEFT_SHOULDER
	,RB: XINPUT_GAMEPAD_RIGHT_SHOULDER
	,LSB: XINPUT_GAMEPAD_LEFT_THUMB
	,RSB: XINPUT_GAMEPAD_RIGHT_THUMB
	,Up: XINPUT_GAMEPAD_DPAD_UP
	,Down: XINPUT_GAMEPAD_DPAD_DOWN
	,Left: XINPUT_GAMEPAD_DPAD_LEFT
	,Right: XINPUT_GAMEPAD_DPAD_RIGHT}


DetectController() {
	Loop 10 {
		idx := A_Index - 1
		if (XInput_GetState(idx)) {
			return idx
		}
	}
	MsgBox Could not detect an xinput controller
	return 0
}

ReadSystemConfig() {
	global configFile
	global controller
	global frameTime
	IniRead controller, %configFile%, System, Controller, auto
	if (controller = "auto") {
		controller := DetectController()
	} else {
		controller := 1 * controller
	}
	OutputDebug % "Using controller " controller

	IniRead fps, %configFile%, System, FPS, 60
	fps := 1 * fps
	if (!fps) {
		MsgBox "Invalid FPS setting"
		Exit 1
	}
	frameTime := Floor(1000 / fps)
	OutputDebug % "Setting " fps " FPS (" frameTime "ms per frame)" 
}

MakeKeyState(key) {
	return {key: key}
}

MakeButton(key, buttonVal, bitmask, mode) {
	obj := {keyType: buttonVal, bitmask: bitmask, ks: MakeKeyState(key), mode: mode}
	return obj
}

CreateButtonFromConfig(key, keyConfig, bitmask) {
	global allButtons
	parts := StrSplit(keyConfig, ":")
	keyBinding := parts[1]
	if (parts[2] = "turbo") {
		mode := "turbo"
	} else if (parts[2] = "toggle") {
		mode := "toggle"
	} else {
		mode := "normal"
	}
	OutputDebug % key ": " keyBinding " " mode
	allButtons.push(MakeButton(keyBinding, key, bitmask, mode))
}

ReadButtonsConfig() {
	global KeyNameMap
	global Bitmask
	global configFile

	keyConfigs := {}
	for name, key in KeyNameMap {
		IniRead keyConf, %configFile% , Buttons, %name%
		if (keyConf != "ERROR") {
			if (keyConf != "NONE") {
				keyConfigs[key] := keyConf
		  	}
		}
	}
	for key, keyConf in keyConfigs {
		CreateButtonFromConfig(key, keyConf, Bitmask[key])
	}
}

ApplyNormalButton(byref keyState, buttonState) {
	if (buttonState != keyState.lastButtonState) {
		key := keyState.key
		if (buttonState) {
			Send {%key% down}
		} else {
			Send {%key% up}
		}
	}
	keyState.lastButtonState := buttonState
}

ApplyToggleButton(byref keyState, buttonState) {
	key := keyState.key
	; On release, change toggle
	if (keyState.lastButtonState && (!buttonState)) {
		keyState.toggleState := (!keyState.toggleState)
		if (keyState.toggleState) {
			Send {%key% down}
		} else {
			Send {%key% up}
		}
	}
	keyState.lastButtonState := buttonState
	; Re-press if the button was released by a normal button
	; Wait until next frame so that the game can detect the
	; release first.
	if (keyState.forcePressNextFrame) {
		Send {%key% down}
		keyState.forcePressNextFrame := 0
	}
	if (keyState.toggleState && (!GetKeyState(keyState.key))) {
		keyState.forcePressNextFrame := 1
	}
}

EngageTurbo(byref keyState, interval) {
	key := keyState.key
	if (keyState.releaseNextFrame) {
		Send {%key% up}
		keyState.releaseNextFrame := 0
	}
	; Waiiiit...
	if (keyState.pauseFrames) {
		keyState.pauseFrames := keyState.pauseFrames - 1
	; FIRE!
	} else {
		Send {%key% down}
		keyState.releaseNextFrame := 1
		keyState.pauseFrames := interval
	}
}

ApplyTurboButton(byref keyState, buttonState) {
	key := keyState.key
	; Pressed
	if (buttonState && (!keyState.lastButtonState)) {
		keyState.engageTurbo := 1
	; Released
	} else if ((!buttonState) && keyState.lastButtonState) {
		keyState.engageTurbo := 0
		if (GetKeyState(keyState.key)) {
			Send {%key% up}
		}
	}
	keyState.lastButtonState := buttonState

	if (keyState.engageTurbo) {
		EngageTurbo(keyState, 2)
	}
}

ApplyTurboTrigger(byref keyState, axisValue) {
	key := keyState.key
	pressed := (axisValue > 0)
	; Pressed
	if (pressed && (!keyState.lastPressed)) {
		keyState.engageTurbo := 1
	; Released
	} else if ((!pressed) && keyState.lastPressed) {
		keyState.engageTurbo := 0
		if (GetKeyState(keyState.key)) {
			Send {%key% up}
		}
	}
	keyState.lastPressed := pressed

	if (keyState.engageTurbo) {
		; axisValue is in [0, 255]
		; Fire between every 18th frame (3.33/sec at 60fps)
		; and every third frame (20/sec at 60fps)
		interval := 17 - Floor(axisValue / 17)
		EngageTurbo(keyState, interval)
	}
}

ApplyButtons(byref state, byref buttons) {
	; Process normal buttons first
	for idx, button in buttons {
		if (button.mode = "normal") {
			if (button.keyType = "LT") {
				ApplyNormalButton(button.ks, state.bLeftTrigger > 0)
			} else if (button.keyType = "RT") {
				ApplyNormalButton(button.ks, state.bRightTrigger > 0)
			} else {
				ApplyNormalButton(button.ks, state.wButtons & button.bitmask)
			}
		}

	}
	; Toggles second as they may need to re-press
	for idx, button in buttons {
		if (button.mode = "toggle") {
			if (button.keyType = "LT") {
				ApplyToggleButton(button.ks, state.bLeftTrigger > 0)
			} else if (button.keyType = "RT") {
				ApplyToggleButton(button.ks, state.bRightTrigger > 0)
			} else {
				ApplyToggleButton(button.ks, state.wButtons & button.bitmask)
			}
		}

	}
	for idx, button in buttons {
		if (button.mode = "turbo") {
			if (button.keyType = "LT") {
				ApplyTurboTrigger(button.ks, state.bLeftTrigger)
			} else if (button.keyType = "RT") {
				ApplyTurboTrigger(button.ks, state.bRightTrigger)
			} else {
				ApplyTurboButton(button.ks, state.wButtons & button.bitmask)
			}
		}
	}
}

ToSpD(value, byref speed, byref direction) {
	direction := Floor(value / Abs(value))
	speed := value * direction
}

MakeJoystickInput(point) {
	ToSpD(point.x, xSpeed, xDirection)
	ToSpD(point.y, ySpeed, yDirection)
	return {x: {speed: xSpeed, direction: xDirection}, y: {speed: ySpeed, direction: yDirection}}
}

JoystickInputToString(joy) {
	return ("X(" joy.x.speed ", " joy.x.direction ") Y(" joy.y.speed ", " joy.y.direction ")")
}

; Map raw joystick input to a point on a [-1, 1] grid
ReadJoystickRaw(xValue, yValue) {
	rawPoint := Point_MakePoint(xValue, yValue)
	normalizedPoint := Point_NormalizePoint(rawPoint, 32768)
	; Joystick input is not a perfect circle, it goes beyond in places
	; Truncate to limit to points within circle with radius 1
	polar := Point_PointToPolar(normalizedPoint)
	truncPolar := Point_TruncatePolar(polar, 1.0)
	truncPoint := Point_PolarToPoint(truncPolar)
	; Map points from circle to grid
	transformed := Point_EllipticalGridTransform(truncPoint)
	return MakeJoystickInput(transformed)
}

; Translate speed from float in [0, 1] to int in [0, max]
TranslateSpeedValue(speed, thresholds) {
	res := 0
	for idx, threshold in thresholds {
		if (speed > threshold) {
			res := res + 1
		} else {
			return res
		}
	}
	return res
}

JoystickTranslateSpeed(byref joyInput, xConfig, yConfig) {
	joyInput.x.speed := TranslateSpeedValue(joyInput.x.speed, xConfig)
	if (joyInput.x.speed = 0) {
		joyInput.x.direction := 0
	}
	joyInput.y.speed := TranslateSpeedValue(joyInput.y.speed, yConfig)
	if (joyInput.y.speed = 0) {
		joyInput.y.direction := 0
	}
}

MakeAxisState(keyPos, keyNeg, axisConfig) {
	obj := {pos: MakeKeyState(keyPos), neg: MakeKeyState(keyNeg), speed: 0, direction: 0, pauseFrames: 0, config: axisConfig}
	return obj
}

MakeJoystickState(keyUp, keyDown, keyLeft, keyRight, xConfig, yConfig) {
	return {x: MakeAxisState(keyRight, keyLeft, xConfig), y: MakeAxisState(keyUp, keyDown, yConfig)}
}

PauseFrames(speed, axisConfig) {
	return (axisConfig.MaxIndex() - speed)
}

ApplyAxisButtons(byref axisState, direction) {
	negState := 0
	posState := 0
	if (direction > 0) {
		posState := 1
	} else if (direction < 0) {
		negState := 1
	}
	ApplyNormalButton(axisState.pos, posState)
	ApplyNormalButton(axisState.neg, negState)
}

ApplyAxis(byref axisInput, byref axisState) {
	; Stop
	if (axisInput.speed = 0) {
		axisState.pauseFrames := PauseFrames(0, axisState.config)
		axisState.speed := 0
		axisState.direction := 0
		ApplyAxisButtons(axisState, 0)
		return
	}
	; Change direction - skip pauseFrames
	if (axisInput.direction != axisState.direction) {
		axisState.pauseFrames := 0
	}
	; Accelerate - skip pauseFrames
	if (axisInput.speed > axisState.speed) {
		axisState.pauseFrames := 0
	}
	; Pause movement for pauseFrames
	if (axisState.pauseFrames > 0) {
		axisState.pauseFrames := axisState.pauseFrames - 1
		ApplyAxisButtons(axisState, 0)
	} else {
		axisState.pauseFrames := PauseFrames(axisInput.speed, axisState.config)
		ApplyAxisButtons(axisState, axisInput.direction)
	}
	axisState.speed := axisInput.speed
	axisState.direction := axisInput.direction
}

; Diagonal movement is weird and zig-zaggy when axes are out of sync
AxisSync(byref axisStateA, byref axisStateB) {
	pauseFrames := Min(axisStateA.pauseFrames, axisStateB.pauseFrames)
	axisStateA.pauseFrames := pauseFrames
	axisStateB.pauseFrames := pauseFrames
}

ApplyJoystick(joyInput, joyState) {
	AxisSync(joyInput.x, joyInput.y)
	ApplyAxis(joyInput.x, joyState.x)
	ApplyAxis(joyInput.y, joyState.y)
}

ParseNumberList(string) {
	values := StrSplit(string, ",", "", 5)
	numbers := []
	for idx, val in values {
		n := (val * 1.0)
		if (n > 0.0) {
			numbers.Push(n)
		}
	}
	return numbers
}

ReadJoystickConfig(section) {
	global configFile
	IniRead upKey, %configFile%, %section%, Up, Up
	IniRead downKey, %configFile%, %section%, Down, Down
	IniRead leftKey, %configFile%, %section%, Left, Left
	IniRead rightKey, %configFile%, %section%, Right, Right
	IniRead xZonesStr, %configFile%, %section%, Xzones, 0.5
	IniRead yZonesStr, %configFile%, %section%, Yzones, 0.5
	xZones := ParseNumberList(yZonesStr)
	yZones := ParseNumberList(xZonesStr)
	if (yZones.MaxIndex() && xZones.MaxIndex()) {
		OutputDebug % section ": " upKey " " downKey " " leftKey " " rightKey
		return MakeJoystickState(upKey, downKey, leftKey, rightKey, yZones, xZones)
	} else {
		return 0
	}
}

NormalizeTrigger(value) {
	return value / 255
}

ReadSystemConfig()
ReadButtonsConfig()
leftJoystick := ReadJoystickConfig("LeftJoystick")
rightJoystick := ReadJoystickConfig("RightJoystick")


Loop {
	state := XInput_GetState(controller)
	if (!state) {
		MsgBox % "Unable to read controller " . controller
		Exit 1
	}

	ApplyButtons(state, allButtons)

	if (leftJoystick) {
		leftJoystickInput := ReadJoystickRaw(state.sThumbLX, state.sThumbLY)
		JoystickTranslateSpeed(leftJoystickInput, leftJoystick.x.config, leftJoystick.y.config)
		ApplyJoystick(leftJoystickInput, leftJoystick)
	}

	if (rightJoystick) {
		rightJoystickInput := ReadJoystickRaw(state.sThumbRX, state.sThumbRY)
		JoystickTranslateSpeed(rightJoystickInput, rightJoystick.x.config, rightJoystick.y.config)
		ApplyJoystick(rightJoystickInput, rightJoystick)
	}

	sleep frameTime
}

