import QtQuick
import Quickshell.Wayland
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

    readonly property var effectiveSourceItem: buildSource ? builtSource : sourceItem
    readonly property rect effectiveSourceRect: buildSource ? Qt.rect(0, 0, 0, 0) : sourceRect

    Item {
        id: builtSource
        width: root.sourceWidth
        height: root.sourceHeight
        x: -100000
        y: -100000
        visible: root.live
        clip: true

        Repeater {
            model: root.buildSource ? (root.windowsModel ?? []) : []
            delegate: Item {
                required property var modelData
                property var windowData: modelData
                property var toplevel: (root.toplevelForAddress && typeof root.toplevelForAddress === "function") ? root.toplevelForAddress(windowData?.address) : null

                x: Math.round(SwitcherCommon.windowLocalX(windowData, root.monitorData) * root.previewScale)
                y: Math.round(SwitcherCommon.windowLocalY(windowData, root.monitorData) * root.previewScale)
                width: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * root.previewScale))
                height: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * root.previewScale))
                clip: true

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: (root.live && toplevel) ? toplevel : null
                    live: root.live
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
