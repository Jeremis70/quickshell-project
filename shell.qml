import QtQuick
import Quickshell
import "battery"
import "volume"
import "brightness"
import "task_switcher"
import "workspace_switcher"

Scope {
    VolumeOSD {}
    MicOSD {}
    PowerSourceOSD {}
    BrightnessOSD {}
    KeyboardBacklightOSD {}
    TaskSwitcher {}
    WorkspaceSwitcher {}
}
