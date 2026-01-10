import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."
import "../config"

Item {
    id: root

    property bool live: true
    property real radius: Math.max(0, Config.theme.panelRadius)
    property real maskRadius: radius
    property real borderRadius: radius

    // Selection / hover styling
    property bool selected: false
    property bool hovered: false
    property color selectedBorderColor: Config.theme.barFill
    property color hoveredBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
    property color normalBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18)
    property int activeBorderWidth: 2
    property int normalBorderWidth: 1

    // Mouse interaction
    property bool hoverEnabled: true
    property int cursorShape: Qt.PointingHandCursor

    signal entered
    signal exited
    signal clicked

    // Preview source mode A: use an existing source item (optionally cropped)
    property var sourceItem: null
    property rect sourceRect: Qt.rect(0, 0, 0, 0)

    // Preview source mode B: build a workspace source from windows
    property bool buildSource: false
    property var windowsModel: null
    property var toplevelForAddress: null
    property var monitorData: null
    property real previewScale: 1.0
    property real sourceWidth: 0
    property real sourceHeight: 0

    // Optional overlay: show app icons centered on each window (buildSource only)
    property bool showWindowIcons: false

    // Tuning for the per-window icon overlay (buildSource only)
    property int windowIconMinPx: 14
    property real windowIconScale: 0.30

    // Optional wallpaper layer behind window previews (only used when buildSource=true)
    property bool wallpaperEnabled: false
    property url wallpaperSource: ""

    // Per-window rounding (only used when buildSource=true)
    property real windowRadiusInset: 4
    property real windowRadius: Math.max(0, root.maskRadius - root.windowRadiusInset)

    // Per-window borders (only used when buildSource=true)
    // If activeWindowAddress is empty, we approximate "active" as the lowest focusHistoryID.
    property bool highlightActiveWindow: false
    property string activeWindowAddress: ""
    property real windowBorderWidth: 0.5
    property color activeWindowBorderColor: Config.theme.barFill
    property color inactiveWindowBorderColor: Config.theme.panelBg

    readonly property string effectiveActiveWindowAddress: {
        if (!root.highlightActiveWindow)
            return "";

        const addr = (root.activeWindowAddress && typeof root.activeWindowAddress === "string") ? root.activeWindowAddress : "";
        if (addr.length)
            return addr;

        const list = root.windowsModel ?? [];
        let bestAddr = "";
        let bestFh = Number.MAX_SAFE_INTEGER;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            const fh = (typeof w?.focusHistoryID === "number") ? w.focusHistoryID : Number.MAX_SAFE_INTEGER;
            if (fh < bestFh) {
                bestFh = fh;
                bestAddr = (typeof w?.address === "string") ? w.address : "";
            }
        }
        return bestAddr;
    }

    readonly property var effectiveSourceItem: buildSource ? builtCompositeSource : sourceItem
    readonly property rect effectiveSourceRect: buildSource ? Qt.rect(0, 0, 0, 0) : sourceRect

    Item {
        id: builtCompositeSource
        width: root.sourceWidth
        height: root.sourceHeight
        x: -100000
        y: -100000
        visible: root.live
        clip: true

        Image {
            anchors.fill: parent
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.wallpaperEnabled && !!root.wallpaperSource
        }

        Item {
            id: builtSource
            anchors.fill: parent
            clip: true

            Repeater {
                model: root.buildSource ? (root.windowsModel ?? []) : []
                delegate: Item {
                    required property var modelData
                    property var windowData: modelData
                    property var toplevel: (root.toplevelForAddress && typeof root.toplevelForAddress === "function") ? root.toplevelForAddress(windowData?.address) : null

                    property var desktopEntry: root.showWindowIcons ? (SwitcherCommon.bestDesktopEntryForWindow(windowData) ?? DesktopEntries.heuristicLookup(windowData?.appId ?? windowData?.appid ?? windowData?.class ?? windowData?.initialClass)) : null
                    readonly property string windowIconKey: String(desktopEntry?.icon ?? "").trim()

                    readonly property string windowAddress: (typeof windowData?.address === "string") ? windowData.address : ""
                    readonly property bool isActiveWindow: root.highlightActiveWindow && (windowAddress.length && root.effectiveActiveWindowAddress.length) ? (windowAddress === root.effectiveActiveWindowAddress) : false

                    x: Math.round(SwitcherCommon.windowLocalX(windowData, root.monitorData) * root.previewScale)
                    y: Math.round(SwitcherCommon.windowLocalY(windowData, root.monitorData) * root.previewScale)
                    width: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * root.previewScale))
                    height: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * root.previewScale))

                    Item {
                        id: windowSource
                        anchors.fill: parent

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: (root.live && toplevel) ? toplevel : null
                            live: root.live
                        }
                    }

                    RoundedMaskedPreview {
                        anchors.fill: parent
                        sourceItem: windowSource
                        radius: root.windowRadius
                        live: root.live
                    }

                    SmartIcon {
                        anchors.centerIn: parent
                        visible: root.showWindowIcons && windowIconKey.length > 0
                        pixelSize: Math.round(Math.max(root.windowIconMinPx, Math.min(parent.width, parent.height) * root.windowIconScale))
                        color: Config.theme.textColor
                        state: "app-icon"
                        icons: ({
                                "app-icon": windowIconKey
                            })
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: root.windowRadius
                        antialiasing: true
                        border.width: root.windowBorderWidth
                        border.color: isActiveWindow ? root.activeWindowBorderColor : root.inactiveWindowBorderColor
                    }
                }
            }
        }
    }

    RoundedMaskedPreview {
        id: maskedPreview
        anchors.fill: parent
        sourceItem: root.effectiveSourceItem
        sourceRect: root.effectiveSourceRect
        radius: root.maskRadius
        live: root.live
        z: 0
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        acceptedButtons: Qt.LeftButton
        cursorShape: root.cursorShape
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: root.clicked()
        z: 1
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.borderRadius
        antialiasing: true
        border.width: (root.selected || root.hovered) ? root.activeBorderWidth : root.normalBorderWidth
        border.color: root.selected ? root.selectedBorderColor : (root.hovered ? root.hoveredBorderColor : root.normalBorderColor)
        z: 2
    }
}
