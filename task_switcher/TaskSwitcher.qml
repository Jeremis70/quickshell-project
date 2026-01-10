import QtQuick
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

    Component {
        id: headerComponent

        Item {
            property var win
            property var overlay
            property var ctx

            readonly property real maxHeaderW: Math.min((win ? (win.sw ?? 0) : 0) * 0.80, 1100)
            readonly property real iconW: (appIcon.visible ? appIcon.width : 0)
            readonly property real titleMaxW: Math.max(0, maxHeaderW - (iconW > 0 ? (iconW + row.spacing) : 0))
            readonly property real titleShownW: Math.min(titleText.implicitWidth, titleMaxW)

            implicitWidth: (iconW > 0 ? (iconW + row.spacing) : 0) + titleShownW
            implicitHeight: row.implicitHeight

            Row {
                id: row
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Widgets.SmartIcon {
                    id: appIcon
                    anchors.verticalCenter: parent.verticalCenter

                    property var currentWindow: taskSwitcher.hoveredWindow ?? taskSwitcher.selectedWindow
                    property var entry: SwitcherCommon.bestDesktopEntryForWindow(currentWindow) ?? DesktopEntries.heuristicLookup(currentWindow?.appId ?? currentWindow?.appid ?? currentWindow?.class ?? currentWindow?.initialClass)

                    readonly property string iconKey: String(entry?.icon ?? "").trim()
                    visible: iconKey.length > 0

                    state: "app-icon"
                    icons: ({
                            "app-icon": iconKey
                        })
                }

                Text {
                    id: titleText
                    width: titleMaxW
                    text: {
                        if (taskSwitcher.windowCount <= 0)
                            return "";
                        const w = taskSwitcher.hoveredWindow ?? taskSwitcher.selectedWindow;
                        return SwitcherCommon.bestWindowTitle(w) ?? "";
                    }
                    color: Config.theme.textColor
                    font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    Component {
        id: bodyComponent

        Item {
            id: body
            property var win
            property var overlay
            property var ctx

            readonly property real sw: win ? (win.sw ?? 0) : 0
            readonly property real sh: win ? (win.sh ?? 0) : 0

            readonly property real mw: win ? (win.monitorWorkspaceWidth ?? 0) : 0
            readonly property real mh: win ? (win.monitorWorkspaceHeight ?? 0) : 0

            readonly property real previewMaxW: Math.min(sw * 0.75, 1000)
            readonly property real previewMaxH: Math.min(sh * 0.60, 650)
            readonly property real thumbSpacing: 10

            readonly property real thumbBasePx: Math.min(Math.min(sw, sh) * 1.0, 1020)
            readonly property real thumbScaleFactor: {
                const m = Math.max(mw, mh);
                if (!(m > 0))
                    return 0.15;
                return thumbBasePx / m;
            }

            readonly property real workspacePreviewScale: {
                if (!(mw > 0) || !(mh > 0))
                    return 0.2;
                return Math.min(previewMaxW / mw, previewMaxH / mh);
            }

            readonly property real previewW: Math.max(1, mw * workspacePreviewScale)
            readonly property real previewH: Math.max(1, mh * workspacePreviewScale)

            function thumbWFor(windowData) {
                const srcW = Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * workspacePreviewScale));
                return Math.max(8, Math.round(srcW * thumbScaleFactor));
            }

            function thumbHFor(windowData) {
                const srcH = Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * workspacePreviewScale));
                return Math.max(8, Math.round(srcH * thumbScaleFactor));
            }

            readonly property real thumbIdealInnerW: {
                const list = taskSwitcher.windowsInActiveWorkspace;
                if (!list || list.length === 0)
                    return 240;
                let total = 0;
                for (let i = 0; i < list.length; i++) {
                    total += thumbWFor(list[i]);
                    if (i > 0)
                        total += thumbSpacing;
                }
                return total;
            }

            readonly property real panelInnerW: ctx ? (ctx.panelInnerW ?? thumbIdealInnerW) : thumbIdealInnerW

            onCtxChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = thumbIdealInnerW;
            }

            onThumbIdealInnerWChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = thumbIdealInnerW;
            }

            Component.onCompleted: {
                if (ctx)
                    ctx.bodyIdealInnerW = thumbIdealInnerW;
            }

            readonly property var thumbLayout: {
                const list = taskSwitcher.windowsInActiveWorkspace ?? [];
                const items = [];
                for (let i = 0; i < list.length; i++) {
                    const addr = (list[i]?.address && typeof list[i].address === "string") ? list[i].address : "";
                    items.push({
                        key: addr,
                        w: thumbWFor(list[i]),
                        h: thumbHFor(list[i])
                    });
                }
                const result = SwitcherCommon.calculateMultiRowLayout(items, panelInnerW, thumbSpacing);
                return {
                    byAddress: result.byKey,
                    totalH: result.totalH
                };
            }

            implicitWidth: panelInnerW
            implicitHeight: thumbFlow.implicitHeight

            Item {
                id: workspaceSource
                width: previewW
                height: previewH
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

                        readonly property real localX: SwitcherCommon.windowLocalX(windowData, win ? win.monitorData : null)
                        readonly property real localY: SwitcherCommon.windowLocalY(windowData, win ? win.monitorData : null)

                        x: Math.round(localX * workspacePreviewScale)
                        y: Math.round(localY * workspacePreviewScale)
                        width: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * workspacePreviewScale))
                        height: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * workspacePreviewScale))
                        clip: true

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: (taskSwitcher.open && toplevel) ? toplevel : null
                            live: true
                        }
                    }
                }
            }

            Item {
                id: thumbFlow
                width: panelInnerW
                implicitHeight: thumbLayout.totalH
                clip: false

                Repeater {
                    model: taskSwitcher.windowsInActiveWorkspace
                    delegate: Item {
                        id: thumb
                        required property var modelData
                        property var windowData: modelData

                        readonly property bool selected: (taskSwitcher.selectedWindow?.address && windowData?.address) ? (taskSwitcher.selectedWindow.address === windowData.address) : false

                        readonly property bool hovered: (taskSwitcher.hoveredAddress && windowData?.address) ? (taskSwitcher.hoveredAddress === windowData.address) : false

                        readonly property real targetScale: (taskSwitcher.windowCount <= 1) ? 1.0 : (selected ? 1.045 : (hovered ? 1.020 : 1.0))
                        readonly property real targetZ: (taskSwitcher.windowCount <= 1) ? 0 : (selected ? 200 : (hovered ? 120 : 0))

                        Behavior on z {
                            NumberAnimation {
                                duration: 90
                            }
                        }

                        readonly property real localX: SwitcherCommon.windowLocalX(windowData, win ? win.monitorData : null)
                        readonly property real localY: SwitcherCommon.windowLocalY(windowData, win ? win.monitorData : null)
                        readonly property real srcX: Math.round(localX * workspacePreviewScale)
                        readonly property real srcY: Math.round(localY * workspacePreviewScale)
                        readonly property real srcW: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * workspacePreviewScale))
                        readonly property real srcH: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * workspacePreviewScale))
                        readonly property real thumbW: Math.max(8, Math.round(srcW * thumbScaleFactor))
                        readonly property real thumbH: Math.max(8, Math.round(srcH * thumbScaleFactor))

                        x: (thumbLayout.byAddress && windowData?.address && thumbLayout.byAddress[windowData.address]) ? thumbLayout.byAddress[windowData.address].x : 0
                        y: (thumbLayout.byAddress && windowData?.address && thumbLayout.byAddress[windowData.address]) ? thumbLayout.byAddress[windowData.address].y : 0
                        width: thumbW
                        height: thumbH
                        clip: false
                        z: targetZ

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

                            PreviewTile {
                                anchors.fill: parent
                                live: taskSwitcher.open

                                sourceItem: workspaceSource
                                sourceRect: Qt.rect(srcX, srcY, srcW, srcH)

                                maskRadius: Math.max(0, Config.theme.panelRadius - 2)
                                borderRadius: Math.max(0, Config.theme.panelRadius - 2)

                                selected: thumb.selected
                                hovered: thumb.hovered
                                selectedBorderColor: Config.theme.barFill
                                hoveredBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
                                normalBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18)
                                activeBorderWidth: 2
                                normalBorderWidth: 1

                                hoverEnabled: true
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
                                    taskSwitcher.focusAddressAndClose(windowData?.address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SwitcherOverlay {
        id: overlay

        open: taskSwitcher.open
        focusedOnly: true
        namespace: "quickshell:task_switcher"

        closeOnModifierRelease: true
        modifierMask: Qt.AltModifier

        panelPadding: 14
        sectionSpacing: 10
        showSeparator: true

        header: headerComponent
        body: bodyComponent

        onCancelRequested: {
            taskSwitcher.open = false;
        }

        onCommitRequested: {
            taskSwitcher.commitSelectionAndClose();
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
