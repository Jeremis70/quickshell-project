import QtQuick
import Quickshell
import "battery"
import "volume"
import "brightness"
import "task_switcher"
import "workspace_switcher"
import "hyprquickshot"
import "launcher"

Scope {
    DesktopIndexerDebug {}
    VolumeOSD {}
    MicOSD {}
    PowerSourceOSD {}
    BrightnessOSD {}
    KeyboardBacklightOSD {}
    TaskSwitcher {}
    WorkspaceSwitcher {}
    HyprQuickshot {}
}
