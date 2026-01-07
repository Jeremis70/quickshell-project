import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../services"
import "../widgets" as Widgets
import "../widgets"

Scope {
    id: taskSwitcher
    property bool open: false
    property int selectedIndex: -1
    property string pendingFocusAddress: ""
    property string hoveredAddress: ""
    readonly property int activeWorkspaceId: HyprlandData.activeWorkspace?.id ?? -1
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property var hoveredWindow: {
        const addr = taskSwitcher.hoveredAddress;
        if (!addr || typeof addr !== "string")
            return null;
        const list = taskSwitcher.windowsInActiveWorkspace ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i]?.address === addr)
                return list[i];
        }
        return null;
    }

    readonly property var windowsInActiveWorkspace: {
        return SwitcherCommon.calculateWindowsInActiveWorkspace(HyprlandData.windowList, taskSwitcher.activeWorkspaceId, Hyprland.focusedMonitor?.id, HyprlandData.activeWindow?.address);
    }

    readonly property int windowCount: windowsInActiveWorkspace?.length ?? 0
    readonly property var selectedWindow: (selectedIndex >= 0 && selectedIndex < windowCount) ? windowsInActiveWorkspace[selectedIndex] : null

    function clampSelection() {
        selectedIndex = SwitcherCommon.clampSelection(selectedIndex, windowCount);
    }

    function selectNext() {
        if (windowCount <= 0)
            return;
        selectedIndex = SwitcherCommon.selectNext(selectedIndex, windowCount);
    }

    function selectPrev() {
        if (windowCount <= 0)
            return;
        selectedIndex = SwitcherCommon.selectPrev(selectedIndex, windowCount);
    }

    function commitSelectionAndClose() {
        const addr = taskSwitcher.selectedWindow?.address;
        pendingFocusAddress = (addr && typeof addr === "string") ? addr : "";
        taskSwitcher.open = false;
        // Focus after the overlay releases keyboard focus.
        if (pendingFocusAddress.length)
            focusAfterClose.restart();
    }

    function focusAddressAndClose(address) {
        pendingFocusAddress = (address && typeof address === "string") ? address : "";
        taskSwitcher.open = false;
        if (pendingFocusAddress.length)
            focusAfterClose.restart();
    }

    Timer {
        id: focusAfterClose
        interval: 30
        repeat: false
        onTriggered: {
            if (!taskSwitcher.pendingFocusAddress.length)
                return;
            SwitcherCommon.dispatchFocusWindowAddress(Hyprland, taskSwitcher.pendingFocusAddress);
            taskSwitcher.pendingFocusAddress = "";
        }
    }

    onOpenChanged: {
        if (open) {
            hoveredAddress = "";
            selectedIndex = 0;
            clampSelection();
        } else {
            hoveredAddress = "";
        }
    }

    onWindowCountChanged: clampSelection()

    Variants {
        id: variants
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
            readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

            visible: taskSwitcher.open && monitorIsFocused
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: "quickshell:task_switcher"
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
            readonly property real previewMaxW: Math.min(sw * 0.75, 1000)
            readonly property real previewMaxH: Math.min(sh * 0.60, 650)
            readonly property real panelContentW: Math.min(sw * 0.80, 1100)
            readonly property real thumbSpacing: 10
            // Target size for the largest window thumbnail (roughly fullscreen).
            // Keep it responsive to screen size so previews don't become tiny.
            readonly property real thumbBasePx: Math.min(Math.min(sw, sh) * 1.0, 1020)
            readonly property real thumbScaleFactor: {
                const mw = win.monitorWorkspaceWidth;
                const mh = win.monitorWorkspaceHeight;
                const m = Math.max(mw, mh);
                if (!(m > 0))
                    return 0.15;
                return win.thumbBasePx / m;
            }

            readonly property real workspacePreviewScale: {
                const mw = win.monitorWorkspaceWidth;
                const mh = win.monitorWorkspaceHeight;
                if (!(mw > 0) || !(mh > 0))
                    return 0.2;
                return Math.min(win.previewMaxW / mw, win.previewMaxH / mh);
            }
            readonly property real previewW: Math.max(1, win.monitorWorkspaceWidth * win.workspacePreviewScale)
            readonly property real previewH: Math.max(1, win.monitorWorkspaceHeight * win.workspacePreviewScale)
            readonly property real panelPadding: 14

            function thumbWFor(windowData) {
                const srcW = Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * win.workspacePreviewScale));
                return Math.max(8, Math.round(srcW * win.thumbScaleFactor));
            }

            function thumbHFor(windowData) {
                const srcH = Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * win.workspacePreviewScale));
                return Math.max(8, Math.round(srcH * win.thumbScaleFactor));
            }

            readonly property real thumbIdealInnerW: {
                const list = taskSwitcher.windowsInActiveWorkspace;
                if (!list || list.length === 0)
                    return 240;
                let total = 0;
                for (let i = 0; i < list.length; i++) {
                    total += win.thumbWFor(list[i]);
                    if (i > 0)
                        total += win.thumbSpacing;
                }
                return total;
            }

            readonly property real panelInnerW: Math.min(win.panelContentW, Math.max(appIcon.pixelSize + 8 + titleText.implicitWidth, win.thumbIdealInnerW))

            // Layout thumbnails into rows, centered horizontally (equal left/right margins per row).
            readonly property var thumbLayout: {
                const list = taskSwitcher.windowsInActiveWorkspace ?? [];
                const items = [];
                for (let i = 0; i < list.length; i++) {
                    const addr = (list[i]?.address && typeof list[i].address === "string") ? list[i].address : "";
                    items.push({
                        key: addr,
                        w: win.thumbWFor(list[i]),
                        h: win.thumbHFor(list[i])
                    });
                }
                const result = SwitcherCommon.calculateMultiRowLayout(items, win.panelInnerW, win.thumbSpacing);
                return {
                    byAddress: result.byKey,
                    totalH: result.totalH
                };
            }

            implicitWidth: win.panelInnerW + win.panelPadding * 2
            implicitHeight: win.panelPadding * 2 + titleText.implicitHeight + 10 + 1 + 10 + thumbFlow.implicitHeight

            margins.left: Math.max(0, (sw - implicitWidth) / 2)
            margins.top: Math.max(0, (sh - implicitHeight) / 2)

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                active: taskSwitcher.open && win.monitorIsFocused
                onCleared: () => {
                    if (!active)
                        taskSwitcher.open = false;
                }
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                visible: taskSwitcher.open && win.monitorIsFocused
                focus: visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        taskSwitcher.open = false;
                        event.accepted = true;
                    }
                }

                Keys.onReleased: event => {
                    // Hyprland drives next/prev via IPC; we only need to close on Alt release.
                    if (taskSwitcher.open && !(event.modifiers & Qt.AltModifier)) {
                        taskSwitcher.commitSelectionAndClose();
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Config.theme.panelRadius
                color: Config.theme.panelBg

                border.width: 1
                border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.20)

                // Hidden source: a scaled-down rendering of the current workspace.
                Item {
                    id: workspaceSource
                    width: win.previewW
                    height: win.previewH
                    x: -100000
                    y: -100000
                    visible: taskSwitcher.open
                    clip: true

                    Repeater {
                        model: taskSwitcher.windowsInActiveWorkspace
                        delegate: Item {
                            required property var modelData
                            property var windowData: modelData
                            property var toplevel: SwitcherCommon.toplevelForAddress(taskSwitcher.toplevels, windowData?.address)

                            readonly property real localX: SwitcherCommon.windowLocalX(windowData, win.monitorData)
                            readonly property real localY: SwitcherCommon.windowLocalY(windowData, win.monitorData)

                            x: Math.round(localX * win.workspacePreviewScale)
                            y: Math.round(localY * win.workspacePreviewScale)
                            width: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * win.workspacePreviewScale))
                            height: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * win.workspacePreviewScale))
                            clip: true

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: (taskSwitcher.open && toplevel) ? toplevel : null
                                live: true
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: win.panelPadding
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 8

                        Widgets.SmartIcon {
                            id: appIcon
                            anchors.verticalCenter: parent.verticalCenter

                            property var currentWindow: taskSwitcher.hoveredWindow ?? taskSwitcher.selectedWindow
                            property var entry: DesktopEntries.heuristicLookup(currentWindow?.appId ?? currentWindow?.appid ?? currentWindow?.class ?? currentWindow?.initialClass)

                            readonly property string iconKey: {
                                const s = String(entry?.icon ?? "").trim();
                                return s;
                            }

                            visible: iconKey.length > 0

                            state: "app-icon"
                            icons: ({
                                    "app-icon": iconKey
                                })
                        }

                        Text {
                            id: titleText
                            text: {
                                if (taskSwitcher.windowCount <= 0)
                                    return "";
                                const w = taskSwitcher.hoveredWindow ?? taskSwitcher.selectedWindow;
                                const title = w?.title ?? "";
                                const initialTitle = w?.initialTitle ?? "";
                                const cls = w?.class ?? w?.initialClass ?? "";
                                return `${initialTitle ? `${initialTitle}` : ""}`;
                            }
                            color: Config.theme.textColor
                            font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                            font.pixelSize: 16
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - appIcon.width - parent.spacing
                        }
                    }

                    Rectangle {
                        width: Math.min(parent.width, 999999)
                        height: 1
                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                    }

                    Item {
                        id: thumbFlow
                        width: win.panelInnerW
                        implicitHeight: win.thumbLayout.totalH
                        // Allow selected/hovered thumbnails to lift/zoom beyond their slot.
                        clip: false

                        Repeater {
                            model: taskSwitcher.windowsInActiveWorkspace
                            delegate: Item {
                                required property var modelData
                                property var windowData: modelData
                                property bool selected: (taskSwitcher.selectedWindow?.address && windowData?.address) ? (taskSwitcher.selectedWindow.address === windowData.address) : false
                                property bool hovered: (taskSwitcher.hoveredAddress && windowData?.address) ? (taskSwitcher.hoveredAddress === windowData.address) : false

                                // --- Lift/zoom tuning (match WorkspaceSwitcher feel) ---
                                readonly property real targetScale: (taskSwitcher.windowCount <= 1) ? 1.0 : (selected ? 1.045 : (hovered ? 1.020 : 1.0))
                                readonly property real targetZ: (taskSwitcher.windowCount <= 1) ? 0 : (selected ? 200 : (hovered ? 120 : 0))

                                Behavior on z {
                                    NumberAnimation {
                                        duration: 90
                                    }
                                }

                                readonly property real localX: SwitcherCommon.windowLocalX(windowData, win.monitorData)
                                readonly property real localY: SwitcherCommon.windowLocalY(windowData, win.monitorData)
                                readonly property real srcX: Math.round(localX * win.workspacePreviewScale)
                                readonly property real srcY: Math.round(localY * win.workspacePreviewScale)
                                readonly property real srcW: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * win.workspacePreviewScale))
                                readonly property real srcH: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * win.workspacePreviewScale))
                                readonly property real thumbW: Math.max(8, Math.round(srcW * win.thumbScaleFactor))
                                readonly property real thumbH: Math.max(8, Math.round(srcH * win.thumbScaleFactor))

                                x: (win.thumbLayout.byAddress && windowData?.address && win.thumbLayout.byAddress[windowData.address]) ? win.thumbLayout.byAddress[windowData.address].x : 0
                                y: (win.thumbLayout.byAddress && windowData?.address && win.thumbLayout.byAddress[windowData.address]) ? win.thumbLayout.byAddress[windowData.address].y : 0
                                width: thumbW
                                height: thumbH
                                // Don't clip: we want the lifted thumbnail to overlap neighbors.
                                clip: false
                                z: targetZ

                                // Animated wrapper: lift + zoom content without moving layout slot.
                                Item {
                                    id: thumbFx
                                    anchors.fill: parent
                                    transformOrigin: Item.Center
                                    scale: targetScale

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    RoundedMaskedPreview {
                                        anchors.fill: parent
                                        sourceItem: workspaceSource
                                        sourceRect: Qt.rect(srcX, srcY, srcW, srcH)
                                        radius: Math.max(0, Config.theme.panelRadius - 2)
                                        live: taskSwitcher.open
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            if (windowData?.address)
                                                taskSwitcher.hoveredAddress = windowData.address;
                                        }
                                        onExited: {
                                            if (taskSwitcher.hoveredAddress === windowData?.address)
                                                taskSwitcher.hoveredAddress = "";
                                        }
                                        onClicked: {
                                            // Mouse click focuses but does not change keyboard selection index.
                                            taskSwitcher.focusAddressAndClose(windowData?.address);
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: Math.max(0, Config.theme.panelRadius - 2)
                                        border.width: (selected || hovered) ? 2 : 1
                                        border.color: selected ? Config.theme.barFill : (hovered ? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18))
                                        z: 100
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "task_switcher"

        function toggle() {
            taskSwitcher.open = !taskSwitcher.open;
        }

        function open() {
            HyprlandData.updateAll();
            taskSwitcher.open = true;
        }

        function close() {
            taskSwitcher.commitSelectionAndClose();
        }

        function next() {
            if (!taskSwitcher.open) {
                HyprlandData.updateAll();
                taskSwitcher.open = true;

                // Active window = index 0, donc first Alt+Tab doit aller à index 1
                taskSwitcher.selectedIndex = 0;
                taskSwitcher.clampSelection();
            }
            taskSwitcher.selectNext();
        }

        function prev() {
            if (!taskSwitcher.open) {
                HyprlandData.updateAll();
                taskSwitcher.open = true;
                taskSwitcher.selectedIndex = 0;
                taskSwitcher.clampSelection();
            }
            taskSwitcher.selectPrev();
        }
    }
}
