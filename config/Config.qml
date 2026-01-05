pragma Singleton
import QtQuick

QtObject {
    id: root

    // ---------------------------
    // Global sections
    // ---------------------------

    readonly property QtObject typography: QtObject {
        // Empty string => fallback to Qt.application.font.family (handled in OSD)
        property string textFontFamily: "JetBrains Mono"
    }

    readonly property QtObject motion: QtObject {
        // Timings (ms)
        readonly property int audioReadyDelayMs: 300
        readonly property int autoHideDelayMs: 2500
        readonly property int slideDurationMs: 250
        readonly property int fadeDurationMs: 200
        readonly property int fillAnimDurationMs: 150

        // Easing
        readonly property int slideEasingOpen: Easing.OutCubic
        readonly property int slideEasingClose: Easing.InCubic
        readonly property int fadeEasing: Easing.InOutQuad
        readonly property int fillEasing: Easing.OutCubic

        // "slide" | "fade" | "slide+fade"
        property string osdAnim: "slide"
    }

    readonly property QtObject placement: QtObject {
        // 0..1 (0 = left/top, 1 = right/bottom)
        property real osdPosX: 0.5
        property real osdPosY: 0.98

        // "left" | "right" | "top" | "bottom"
        property string osdEnterFrom: "bottom"

        // distance offscreen (px)
        property int osdOffscreenPx: 24
    }

    readonly property QtObject theme: QtObject {
        // Look/colors
        readonly property color panelBg: "#ff2c2c2c"
        readonly property color barBg:   "#ff9f9f9f"
        readonly property color barFill: "#FF62E0FF"
        readonly property color textColor: "#FFFFFFFF"
        readonly property color windowPanelColor: "transparent"

        // Shape
        readonly property real panelRadius: 10
    }

    readonly property QtObject layout: QtObject {
        // Shared spacing
        readonly property int contentLeftMargin: 15
        readonly property int contentRightMargin: 15

        // Shared slider geometry defaults
        readonly property int barHeight: 5
        readonly property int barRadius: 20
    }

    // ---------------------------
    // Per-OSD sections
    // ---------------------------

    readonly property QtObject volume: QtObject {
        // Window/layout
        readonly property int panelWidth: 200
        readonly property int panelHeight: 50

        // Theme overrides
        property color bg: root.theme.panelBg
        property color barBg: root.theme.barBg
        property color barFill: root.theme.barFill
        property color windowColor: root.theme.windowPanelColor

        // Motion / placement overrides
        property int  autoHideDelayMs: root.motion.autoHideDelayMs
        property bool hoverPausesAutoHide: true
        property real posX: root.placement.osdPosX
        property real posY: root.placement.osdPosY
        property string enterFrom: root.placement.osdEnterFrom
        property int offscreenPx: root.placement.osdOffscreenPx

        property string animMode: root.motion.osdAnim
        property int slideDurationMs: root.motion.slideDurationMs
        property int slideEasingOpen: root.motion.slideEasingOpen
        property int slideEasingClose: root.motion.slideEasingClose
        property int fadeDurationMs: root.motion.fadeDurationMs
        property int fadeEasing: root.motion.fadeEasing
        property real opacityShown: 1.0
        property real opacityHidden: 0.0

        // Text / sizing
        readonly property int textFontSize: 12
        readonly property int textLeftMargin: 5

        // Slider
        readonly property int barHeight: root.layout.barHeight
        readonly property int barRadius: root.layout.barRadius
        property int barHitExtraY: 12
        property int barHitExtraX: 6

        // Icons
        readonly property int iconSize: 18
        readonly property string iconFontFamily: "Segoe Fluent Icons"
        readonly property real iconLowThreshold: 0.33
        readonly property real iconMediumThreshold: 0.66

        readonly property var icons: ({
            muted: "\uE74F",
            zero: "\uE992",
            low: "\uE993",
            medium: "\uE994",
            high: "\uE995"
        })
    }

    readonly property QtObject mic: QtObject {
        // Window/layout
        readonly property int panelWidth: 75
        readonly property int panelHeight: 75

        // Theme overrides
        property color bg: root.theme.panelBg
        property color windowColor: root.theme.windowPanelColor

        // Placement overrides
        property int  autoHideDelayMs: 1000
        property bool hoverPausesAutoHide: true
        property real posX: 0.5
        property real posY: 0.7
        property string enterFrom: root.placement.osdEnterFrom
        property int offscreenPx: root.placement.osdOffscreenPx

        // Motion overrides (mic is fade)
        property string animMode: "fade"
        property int slideDurationMs: root.motion.slideDurationMs
        property int slideEasingOpen: root.motion.slideEasingOpen
        property int slideEasingClose: root.motion.slideEasingClose
        property int fadeDurationMs: 350
        property int fadeEasing: root.motion.fadeEasing
        property real opacityShown: 1.0
        property real opacityHidden: 0.0

        // Icons
        readonly property int iconSize: 40
        readonly property string iconFontFamily: "Segoe Fluent Icons"
        readonly property var icons: ({
            muted: "microphone-sensitivity-muted",
            unmuted: "microphone-sensitivity-high"
        })
    }

    readonly property QtObject keyboardBacklight: QtObject {
        // Window/layout
        readonly property int panelWidth: 75
        readonly property int panelHeight: 75

        // Theme overrides
        property color bg: root.theme.panelBg
        property color windowColor: root.theme.windowPanelColor

        // Placement overrides
        property int  autoHideDelayMs: 1000
        property bool hoverPausesAutoHide: true
        property real posX: 0.5
        property real posY: 0.7
        property string enterFrom: root.placement.osdEnterFrom
        property int offscreenPx: root.placement.osdOffscreenPx

        // Motion overrides (keyboard backlight is fade by default)
        property string animMode: "fade"
        property int slideDurationMs: root.motion.slideDurationMs
        property int slideEasingOpen: root.motion.slideEasingOpen
        property int slideEasingClose: root.motion.slideEasingClose
        property int fadeDurationMs: 350
        property int fadeEasing: root.motion.fadeEasing
        property real opacityShown: 1.0
        property real opacityHidden: 0.0

        // Sysfs backlight paths (override per machine)
        // Example: "/sys/class/backlight/amdgpu_bl1/brightness"
        property string brightnessPath: "/sys/class/leds/tpacpi::kbd_backlight/brightness"
        property string maxBrightnessPath: "/sys/class/leds/tpacpi::kbd_backlight/max_brightness"


        // Icons
        readonly property int iconSize: 40
        readonly property string iconFontFamily: "Segoe Fluent Icons"
        // State keys are defined by the OSD QML (currently: muted/unmuted)
        readonly property var icons: ({
            off: "keyboard-backlight-off",
            low: "keyboard-backlight-low",
            high: "keyboard-backlight-high"
        })
    }

    readonly property QtObject powerSource: QtObject {
        // Window/layout
        readonly property int panelWidth: 75
        readonly property int panelHeight: 75

        // Theme overrides
        property color bg: root.theme.panelBg
        property color windowColor: root.theme.windowPanelColor

        // Placement overrides
        property int  autoHideDelayMs: 1000
        property bool hoverPausesAutoHide: false
        property real posX: 0.5
        property real posY: 0.7
        property string enterFrom: root.placement.osdEnterFrom
        property int offscreenPx: root.placement.osdOffscreenPx

        // Motion overrides (power source is fade by default)
        property string animMode: "fade"
        property int slideDurationMs: root.motion.slideDurationMs
        property int slideEasingOpen: root.motion.slideEasingOpen
        property int slideEasingClose: root.motion.slideEasingClose
        property int fadeDurationMs: 350
        property int fadeEasing: root.motion.fadeEasing
        property real opacityShown: 1.0
        property real opacityHidden: 0.0

        // Sysfs power supply path (override per machine)
        // Example: "/sys/class/power_supply/AC/online"
        property string onlinePath: "/sys/class/power_supply/AC/online"
        property int pollIntervalMs: 250

        // Icons
        readonly property int iconSize: 40
        readonly property var icons: ({
            ac: "power_ac_on",
            no_ac: "power_ac_off"
        })
    }

    readonly property QtObject brightness: QtObject {
        // Window/layout
        readonly property int panelWidth: 200
        readonly property int panelHeight: 50

        // Theme overrides
        property color bg: root.theme.panelBg
        property color barBg: root.theme.barBg
        property color barFill: root.theme.barFill
        property color windowColor: root.theme.windowPanelColor

        // Motion / placement overrides
        property int  autoHideDelayMs: root.motion.autoHideDelayMs
        property bool hoverPausesAutoHide: true
        property real posX: root.placement.osdPosX
        property real posY: root.placement.osdPosY
        property string enterFrom: root.placement.osdEnterFrom
        property int offscreenPx: root.placement.osdOffscreenPx

        property string animMode: root.motion.osdAnim
        property int slideDurationMs: root.motion.slideDurationMs
        property int slideEasingOpen: root.motion.slideEasingOpen
        property int slideEasingClose: root.motion.slideEasingClose
        property int fadeDurationMs: root.motion.fadeDurationMs
        property int fadeEasing: root.motion.fadeEasing
        property real opacityShown: 1.0
        property real opacityHidden: 0.0

        // Text / sizing
        readonly property int textFontSize: 12
        readonly property int textLeftMargin: 5

        // Slider
        readonly property int barHeight: root.layout.barHeight
        readonly property int barRadius: root.layout.barRadius
        property int barHitExtraY: 12
        property int barHitExtraX: 6

        // Brightness behavior
        readonly property real exponentK: 4.0
        property int minPercent: 10

        // Sysfs backlight paths (override per machine)
        // Example: "/sys/class/backlight/amdgpu_bl1/brightness"
        property string brightnessPath: "/sys/class/backlight/intel_backlight/brightness"
        property string maxBrightnessPath: "/sys/class/backlight/intel_backlight/max_brightness"

        // Icons
        readonly property int iconSize: 18
        readonly property var icons: ({
            brightness_1: "display-brightness-1",
            brightness_2: "display-brightness-2",
            brightness_3: "display-brightness-3",
            brightness_4: "display-brightness-4",
            brightness_5: "display-brightness-5",
            brightness_6: "display-brightness-6",
            brightness_7: "display-brightness-7"
        })
        readonly property var bucketThresholds: ([15, 30, 45, 60, 75, 90])
    }
}
