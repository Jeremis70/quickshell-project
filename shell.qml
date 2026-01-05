import QtQuick
import Quickshell
import "battery"
import "volume"
import "brightness"

Scope {
	VolumeOSD {}
	MicOSD {}
	PowerSourceOSD {}
	BrightnessOSD {}
	KeyboardBacklightOSD {}
}