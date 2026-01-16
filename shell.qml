import QtQuick
import Quickshell
import "battery"
import "volume"
import "brightness"
import "task_switcher"
import "workspace_switcher"
import "hyprquickshot"
import "launcher"
import "copypanel"

Scope {
    DesktopIndexerDaemon {}
    Launcher {}

    VolumeOSD {}
    MicOSD {}
    PowerSourceOSD {}
    BrightnessOSD {}
    KeyboardBacklightOSD {}

    TaskSwitcher {}
    WorkspaceSwitcher {}

    HyprQuickshot {}

    CopyPanel {}
}
