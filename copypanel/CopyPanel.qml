import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import "../config"
import "../widgets"

Scope {
    id: root

    // Public state
    property bool open: false
    property string tab: "clipboard" // clipboard|emoji|gif|kaomoji|symbols

    // UI-only search text (each mode can interpret it however it wants)
    property string searchText: ""

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }

    function openPanel(tabName) {
        root.tab = (tabName && tabName.length) ? tabName : "clipboard";
        root.open = true;
    }

    onOpenChanged: {
        if (root.open)
            root.searchText = "";
    }

    // -----------------------------
    // Pages (TODO stubs)
    // -----------------------------

    Component {
        id: clipboardPage
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                text: "TODO: implémenter le mode Clipboard"
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.65)
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: emojiPage
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                text: "TODO: implémenter le mode Emoji"
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.65)
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: gifPage
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                text: "TODO: implémenter le mode GIF"
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.65)
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: kaomojiPage
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                text: "TODO: implémenter le mode Kaomoji"
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.65)
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: symbolsPage
        Item {
            anchors.fill: parent
            Text {
                anchors.centerIn: parent
                text: "TODO: implémenter le mode Symbols"
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.65)
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 12
            }
        }
    }

    // -----------------------------
    // UI
    // -----------------------------

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
            readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

            property real shown: root.open ? 1.0 : 0.0
            Behavior on shown {
                NumberAnimation {
                    duration: root.open ? 180 : 140
                    easing.type: root.open ? Easing.OutCubic : Easing.InCubic
                }
            }

            visible: shown > 0.001 && monitorIsFocused
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: "quickshell:copypanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open && monitorIsFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                left: true
                top: true
                right: true
                bottom: true
            }

            readonly property var scr: win.screen
            readonly property real sw: scr ? scr.width : 0
            readonly property real sh: scr ? scr.height : 0

            readonly property real panelW: Math.min(420, Math.max(340, sw * 0.30))
            readonly property real panelH: Math.min(560, Math.max(420, sh * 0.62))

            HyprlandFocusGrab {
                windows: [win]
                active: root.open && win.monitorIsFocused
                onCleared: () => {
                    if (!active)
                        root.close();
                }
            }

            FocusScope {
                anchors.fill: parent
                visible: win.visible
                focus: visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                        return;
                    }
                }

                // Click outside closes.
                MouseArea {
                    id: outsideClick
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    propagateComposedEvents: true
                    onPressed: mouse => {
                        const p = panelContainer.mapFromItem(outsideClick, mouse.x, mouse.y);
                        const inside = p.x >= 0 && p.y >= 0 && p.x <= panelContainer.width && p.y <= panelContainer.height;
                        if (!inside)
                            root.close();
                        mouse.accepted = false;
                    }
                }

                Item {
                    id: panelContainer
                    width: win.panelW
                    height: win.panelH

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 18
                    anchors.bottomMargin: 18

                    opacity: win.shown
                    transform: Translate {
                        y: (1.0 - win.shown) * 14
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Config.theme.panelBg
                        border.width: 1
                        border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Top tabs (Windows-like)
                        Item {
                            id: tabsBar
                            width: parent.width
                            height: 34

                            Row {
                                id: tabsRow
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                function tabBtn(tabId, iconName) {
                                    return ({
                                            tabId,
                                            iconName
                                        });
                                }

                                Repeater {
                                    model: [tabsRow.tabBtn("clipboard", "edit-paste"), tabsRow.tabBtn("emoji", "face-smile"), tabsRow.tabBtn("gif", "image-x-generic"), tabsRow.tabBtn("kaomoji", "accessories-character-map"), tabsRow.tabBtn("symbols", "insert-text")]

                                    delegate: Item {
                                        required property var modelData
                                        width: 34
                                        height: 34

                                        readonly property bool active: root.tab === modelData.tabId

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            color: active ? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.12) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: active ? Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.55) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                                        }

                                        SmartIcon {
                                            anchors.centerIn: parent
                                            pixelSize: 18
                                            color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, active ? 0.95 : 0.80)
                                            state: "default"
                                            icons: ({
                                                    default: modelData.iconName
                                                })
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                root.tab = modelData.tabId;
                                                root.searchText = "";
                                            }
                                        }
                                    }
                                }
                            }

                            // Close button
                            Item {
                                width: 34
                                height: 34
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                                }

                                SmartIcon {
                                    anchors.centerIn: parent
                                    pixelSize: 16
                                    color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.85)
                                    state: "default"
                                    icons: ({
                                            default: "window-close"
                                        })
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.close()
                                }
                            }
                        }

                        // Search bar
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: 12
                            color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                SmartIcon {
                                    pixelSize: 16
                                    color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.70)
                                    state: "default"
                                    icons: ({
                                            default: "edit-find"
                                        })
                                }

                                TextInput {
                                    id: searchInput
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16 - 10
                                    color: Config.theme.textColor
                                    selectionColor: Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.45)
                                    selectedTextColor: Config.theme.textColor
                                    font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                                    font.pixelSize: 12
                                    clip: true

                                    focus: root.open
                                    text: root.searchText
                                    onTextEdited: root.searchText = text

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: (searchInput.text ?? "").length === 0
                                        text: root.tab === "clipboard" ? "Search clipboard" : (root.tab === "emoji" ? "Search emoji" : (root.tab === "gif" ? "Search GIF" : (root.tab === "kaomoji" ? "Search kaomoji" : "Search symbols")))
                                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
                                        font.family: searchInput.font.family
                                        font.pixelSize: searchInput.font.pixelSize
                                    }
                                }
                            }
                        }

                        // Body
                        Loader {
                            width: parent.width
                            height: parent.height - tabsBar.height - 36 - 20
                            active: true
                            sourceComponent: root.tab === "clipboard" ? clipboardPage : (root.tab === "emoji" ? emojiPage : (root.tab === "gif" ? gifPage : (root.tab === "kaomoji" ? kaomojiPage : symbolsPage)))
                        }
                    }
                }
            }
        }
    }

    // -----------------------------
    // IPC
    // -----------------------------

    IpcHandler {
        target: "copypanel"

        function isActive(): bool {
            return root.open;
        }

        function toggle() {
            root.toggle();
        }

        function open() {
            root.openPanel("clipboard");
        }

        function openTab(tabName: string) {
            root.openPanel(tabName);
        }

        function close() {
            root.close();
        }
    }
}
