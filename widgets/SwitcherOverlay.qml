import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../services"

Scope {
    id: overlay

    property bool open: false
    property bool focusedOnly: true
    property string namespace: ""

    property bool closeOnModifierRelease: false
    property int modifierMask: 0

    property real panelPadding: 14
    property real sectionSpacing: 10
    property bool showSeparator: true

    property Component header: null
    property Component body: null

    signal cancelRequested
    signal commitRequested

    Variants {
        id: variants
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
            readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

            visible: overlay.open && (!overlay.focusedOnly || monitorIsFocused)
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: overlay.namespace
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                left: true
                top: true
                right: false
                bottom: false
            }

            readonly property var scr: win.screen
            readonly property real sw: scr ? scr.width : 0
            readonly property real sh: scr ? scr.height : 0

            readonly property var monitorData: HyprlandData.monitors.find(m => m.id === monitor?.id)
            readonly property real monitorWorkspaceWidth: SwitcherCommon.monitorWorkspaceWidth(monitorData, monitor)
            readonly property real monitorWorkspaceHeight: SwitcherCommon.monitorWorkspaceHeight(monitorData, monitor)

            implicitWidth: frame.implicitWidth
            implicitHeight: frame.implicitHeight

            margins.left: Math.max(0, (sw - implicitWidth) / 2)
            margins.top: Math.max(0, (sh - implicitHeight) / 2)

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                active: overlay.open && win.monitorIsFocused
                onCleared: () => {
                    if (!active)
                        overlay.cancelRequested();
                }
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                visible: overlay.open && win.monitorIsFocused
                focus: visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        overlay.cancelRequested();
                        event.accepted = true;
                    }
                }

                Keys.onReleased: event => {
                    if (!overlay.closeOnModifierRelease)
                        return;
                    if (overlay.open && !(event.modifiers & overlay.modifierMask)) {
                        overlay.commitRequested();
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                id: frame
                width: win.implicitWidth
                height: win.implicitHeight
                radius: Config.theme.panelRadius
                color: Config.theme.panelBg

                implicitWidth: column.implicitWidth + overlay.panelPadding * 2
                implicitHeight: column.implicitHeight + overlay.panelPadding * 2

                border.width: 1
                border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.20)

                QtObject {
                    id: ctx
                    property real headerTitleImplicitW: 0
                    property real headerIconW: 0
                    property real bodyIdealInnerW: 0
                    property real panelInnerW: 0
                }

                Column {
                    id: column
                    x: overlay.panelPadding
                    y: overlay.panelPadding
                    spacing: overlay.sectionSpacing

                    Loader {
                        id: headerLoader
                        sourceComponent: overlay.header
                        visible: overlay.header !== null
                        onLoaded: {
                            item.win = win;
                            item.overlay = overlay;
                            item.ctx = ctx;
                        }
                    }

                    Rectangle {
                        width: Math.min(parent.width, 999999)
                        height: 1
                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                        visible: overlay.showSeparator && headerLoader.item
                    }

                    Loader {
                        id: bodyLoader
                        sourceComponent: overlay.body
                        visible: overlay.body !== null
                        onLoaded: {
                            item.win = win;
                            item.overlay = overlay;
                            item.ctx = ctx;
                        }
                    }
                }
            }
        }
    }
}
