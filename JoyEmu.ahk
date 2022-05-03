; Copyright 2022 Jerome Boisvert-Chouinard
#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
XInput_Init()


controller := 1
fps := 60
configFile := "JoyEmu.ini"
OutputDebug Loading config from %configFile%

frameTime := Floor(1000 / fps)

; Set later by ReadConfig* functions
allButtons := []
leftJoystick := 0
rightJoystick := 0
leftTrigger := 0
rightTrigger := 0


Bitmask := {A: XINPUT_GAMEPAD_A
	,B: XINPUT_GAMEPAD_B
	,X: XINPUT_GAMEPAD_X
	,Y: XINPUT_GAMEPAD_Y
	,L1: XINPUT_GAMEPAD_LEFT_SHOULDER
	,R1: XINPUT_GAMEPAD_RIGHT_SHOULDER
	,Start: XINPUT_GAMEPAD_START
	,Back: XINPUT_GAMEPAD_BACK
	,L3: XINPUT_GAMEPAD_LEFT_THUMB
	,R3: XINPUT_GAMEPAD_RIGHT_THUMB
	,Up: XINPUT_GAMEPAD_DPAD_UP
	,Down: XINPUT_GAMEPAD_DPAD_DOWN
	,Left: XINPUT_GAMEPAD_DPAD_LEFT
	,Right: XINPUT_GAMEPAD_DPAD_RIGHT}


MakeKeyState(key) {
	obj := {key: key, state: 0}
	return obj
}

MakeButton(key, bitmask) {
	obj := {bitmask: bitmask, ks: MakeKeyState(key)}
	return obj
}

ReadButtonConfig(key, bitmask) {
	global allButtons
	global configFile
	IniRead keyBinding, %configFile% , Buttons, %key%
	if (keyBinding = "ERROR") {
		return
	}
	OutputDebug % key ": " keyBinding
	allButtons.push(MakeButton(keyBinding, bitmask))
}

ReadButtonsConfig() {
	global Bitmask
	for key, bitmask in Bitmask {
		ReadButtonConfig(key, bitmask)
	}
}

; Press or release key as needed
ApplyKeyState(byref keyState, targetState) {
	key := keyState.key
	currentState := keyState.state
	if (currentState && (!targetState)) {
		Send {%key% up}
	}
	if ((!currentState) && targetState) {
		Send {%key% down}
	}
	keyState.state := targetState
}

ApplyButtons(wButtons, byref buttons) {
	for idx, button in buttons {
		ApplyKeyState(button.ks, wButtons & button.bitmask)
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
	; Joystick input is not a circle, it's a weird elliptial
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
	ApplyKeyState(axisState.pos, posState)
	ApplyKeyState(axisState.neg, negState)
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

; Movement feels weird and jittery when axes are out of sync
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
	values := StrSplit(string, ",", 5)
	numbers := []
	for idx, val in values {
		n := val * 1
		if (n) {
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
	IniRead xZonesStr, %configFile%, %section%, Xzones
	IniRead yZonesStr, %configFile%, %section%, Yzones
	xZones := ParseNumberList(yZonesStr)
	yZones := ParseNumberList(xZonesStr)
	if (yZones.MaxIndex() && xZones.MaxIndex()) {
		OutputDebug % section ": " upKey " " downKey " " leftKey " " rightKey
		return MakeJoystickState(upKey, downKey, leftKey, rightKey, xZones, yZones)
	} else {
		return 0
	}
}

ReadTriggerConfig(section) {
	return
}

ReadButtonsConfig()

leftJoystick := ReadJoystickConfig("LeftJoystick")
rightJoystick := ReadJoystickConfig("RightJoystick")

Loop {
	state := XInput_GetState(controller)
	if (state = 0) {
		MsgBox % "Unable to read controller " . controller
		Exit 1
	}

	ApplyButtons(state.wButtons, allButtons)

	if (leftJoystick != 0) {
		leftJoystickInput := ReadJoystickRaw(state.sThumbLX, state.sThumbLY)
		JoystickTranslateSpeed(leftJoystickInput, leftJoystick.x.config, leftJoystick.y.config)
		ApplyJoystick(leftJoystickInput, leftJoystick)
	}

	Sleep frameTime
}
