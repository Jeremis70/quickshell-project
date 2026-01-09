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

    // Live snapshot of currently held modifiers (from key events).
    // Useful for secondary modes (e.g. show extra overlays when Alt is held).
    property int currentModifiers: 0

    property real panelPadding: 14
    property real sectionSpacing: 10
    property bool showSeparator: true

    // Used to cap the overlay width: min(screenWidth * panelWidthRatio, panelMaxWidth)
    property real panelWidthRatio: 0.80
    property real panelMaxWidth: 1100

    property Component header: null
    property Component body: null

    signal cancelRequested
    signal commitRequested

    // Forward raw key events to consumers (e.g. for toggle modes).
    signal keyPressed(int key, int modifiers)
    signal keyReleased(int key, int modifiers)

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
                    overlay.currentModifiers = event.modifiers;
                    overlay.keyPressed(event.key, event.modifiers);
                    if (event.key === Qt.Key_Escape) {
                        overlay.cancelRequested();
                        event.accepted = true;
                    }
                }

                Keys.onReleased: event => {
                    overlay.currentModifiers = event.modifiers;
                    overlay.keyReleased(event.key, event.modifiers);
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

                implicitWidth: column.width + overlay.panelPadding * 2
                implicitHeight: column.implicitHeight + overlay.panelPadding * 2

                border.width: 1
                border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.20)

                QtObject {
                    id: ctx
                    property real headerTitleImplicitW: 0
                    property real headerIconW: 0
                    property real bodyIdealInnerW: 0
                    property real panelInnerW: {
                        const maxWByRatio = win.sw * overlay.panelWidthRatio;
                        const maxW = (overlay.panelMaxWidth > 0) ? Math.min(maxWByRatio, overlay.panelMaxWidth) : maxWByRatio;
                        const headerW = headerLoader.item ? headerLoader.implicitWidth : 0;
                        const bodyW = (ctx.bodyIdealInnerW > 0) ? ctx.bodyIdealInnerW : 0;
                        return Math.min(maxW, Math.max(headerW, bodyW));
                    }
                }

                Column {
                    id: column
                    x: overlay.panelPadding
                    y: overlay.panelPadding
                    spacing: overlay.sectionSpacing
                    width: ctx.panelInnerW

                    Loader {
                        id: headerLoader
                        sourceComponent: overlay.header
                        visible: overlay.header !== null
                        width: ctx.panelInnerW
                        onLoaded: {
                            item.win = win;
                            item.overlay = overlay;
                            item.ctx = ctx;
                        }
                    }

                    Rectangle {
                        width: ctx.panelInnerW
                        height: 1
                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                        visible: overlay.showSeparator && headerLoader.item
                    }

                    Loader {
                        id: bodyLoader
                        sourceComponent: overlay.body
                        visible: overlay.body !== null
                        width: ctx.panelInnerW
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
