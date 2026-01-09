import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../services"
import "../widgets"

Scope {
    id: workspaceSwitcher
    property bool open: false

    // "Alt mode": toggled by pressing Alt (on/off).
    property bool altMode: false

    // Drag state for moving a window to another workspace.
    property string draggingWindowAddress: ""
    property int draggingFromWorkspaceId: -1
    property int draggingTargetWorkspaceId: -1

    // Freeze workspace ordering while open to avoid jittery re-sorts when focus history changes.
    property var frozenWorkspaceOrder: ([])

    property int selectedIndex: -1
    property int hoveredWorkspaceId: -1
    property int pendingSwitchWorkspaceId: -1

    readonly property int activeWorkspaceId: HyprlandData.activeWorkspace?.id ?? -1
    readonly property var toplevels: ToplevelManager.toplevels

    readonly property var selectedWorkspace: (selectedIndex >= 0 && selectedIndex < activeWorkspaces.length) ? activeWorkspaces[selectedIndex] : null

    readonly property var hoveredWorkspace: {
        const id = workspaceSwitcher.hoveredWorkspaceId;
        if (!(id > 0))
            return null;
        const list = workspaceSwitcher.activeWorkspaces ?? [];
        for (let i = 0; i < list.length; i++) {
            if ((list[i]?.id ?? -1) === id)
                return list[i];
        }
        return null;
    }

    readonly property bool showAllWorkspaces: !!Config.workspaceSwitcher.showAllWorkspaces
    readonly property int allWorkspacesCount: Math.max(1, Config.workspaceSwitcher.allWorkspacesCount ?? 10)
    readonly property string activeWorkspaceOrder: String(Config.workspaceSwitcher.activeWorkspaceOrder ?? "mru")
    readonly property string orderedSelectionStart: String(Config.workspaceSwitcher.orderedSelectionStart ?? "current")

    readonly property var activeWorkspacesUnfrozen: {
        const wsList = HyprlandData.workspaces;
        const windows = HyprlandData.windowList;
        const activeId = workspaceSwitcher.activeWorkspaceId;
        const focusedMon = Hyprland.focusedMonitor?.id;

        if (workspaceSwitcher.showAllWorkspaces) {
            const byId = ({});
            const list = wsList ?? [];
            for (let i = 0; i < list.length; i++) {
                const id = list[i]?.id ?? -1;
                if (id > 0)
                    byId[id] = list[i];
            }
            const out = [];
            for (let id = 1; id <= workspaceSwitcher.allWorkspacesCount; id++) {
                out.push(byId[id] ?? ({
                        id
                    }));
            }
            return out;
        }

        if (workspaceSwitcher.activeWorkspaceOrder === "ordered")
            return SwitcherCommon.calculateActiveWorkspacesOrdered(wsList, windows, activeId, focusedMon);

        return SwitcherCommon.calculateActiveWorkspaces(wsList, windows, activeId, focusedMon);
    }

    readonly property var activeWorkspaces: {
        const current = workspaceSwitcher.activeWorkspacesUnfrozen ?? [];
        if (!workspaceSwitcher.open)
            return current;

        const order = workspaceSwitcher.frozenWorkspaceOrder ?? [];
        if (!order.length)
            return current;

        const byId = ({});
        for (let i = 0; i < current.length; i++) {
            const id = current[i]?.id ?? -1;
            if (id > 0)
                byId[id] = current[i];
        }

        const result = [];
        for (let i = 0; i < order.length; i++) {
            const id = order[i];
            if (id > 0 && byId[id]) {
                result.push(byId[id]);
                delete byId[id];
            }
        }

        // Append any newly-visible workspaces without re-sorting the existing order.
        const remaining = [];
        for (const k in byId) {
            const id = parseInt(k);
            if (!isNaN(id))
                remaining.push(byId[id]);
        }
        remaining.sort((a, b) => (a?.id ?? 0) - (b?.id ?? 0));
        return result.concat(remaining);
    }

    function clampSelection() {
        const count = workspaceSwitcher.activeWorkspaces?.length ?? 0;
        selectedIndex = SwitcherCommon.clampSelection(selectedIndex, count);
    }

    function selectNext() {
        const count = workspaceSwitcher.activeWorkspaces?.length ?? 0;
        if (count <= 0)
            return;
        selectedIndex = SwitcherCommon.selectNext(selectedIndex, count);
    }

    function selectPrev() {
        const count = workspaceSwitcher.activeWorkspaces?.length ?? 0;
        if (count <= 0)
            return;
        selectedIndex = SwitcherCommon.selectPrev(selectedIndex, count);
    }

    function commitSelectionAndClose() {
        const wsId = workspaceSwitcher.selectedWorkspace?.id ?? -1;
        pendingSwitchWorkspaceId = (wsId > 0) ? wsId : -1;
        workspaceSwitcher.open = false;
        if (pendingSwitchWorkspaceId > 0)
            switchAfterClose.restart();
    }

    function switchWorkspaceAndClose(wsId) {
        pendingSwitchWorkspaceId = (wsId > 0) ? wsId : -1;
        workspaceSwitcher.open = false;
        if (pendingSwitchWorkspaceId > 0)
            switchAfterClose.restart();
    }

    Timer {
        id: switchAfterClose
        interval: 30
        repeat: false
        onTriggered: {
            const wsId = workspaceSwitcher.pendingSwitchWorkspaceId;
            workspaceSwitcher.pendingSwitchWorkspaceId = -1;
            if (!(wsId > 0))
                return;
            SwitcherCommon.dispatchSwitchWorkspace(Hyprland, workspaceSwitcher.activeWorkspaceId, wsId);
        }
    }

    onOpenChanged: {
        if (open) {
            altMode = !!Config.workspaceSwitcher.altModeDefaultActive;
            draggingWindowAddress = "";
            draggingFromWorkspaceId = -1;
            draggingTargetWorkspaceId = -1;

            // Snapshot workspace order at open time.
            frozenWorkspaceOrder = (workspaceSwitcher.activeWorkspacesUnfrozen ?? []).map(w => w?.id ?? -1).filter(id => id > 0);

            hoveredWorkspaceId = -1;
            // Avoid switching to workspace 1 on close when order isn't rotated.
            if (workspaceSwitcher.showAllWorkspaces || workspaceSwitcher.activeWorkspaceOrder === "ordered") {
                if (workspaceSwitcher.orderedSelectionStart === "first") {
                    selectedIndex = 0;
                } else {
                    const list = workspaceSwitcher.activeWorkspacesUnfrozen ?? [];
                    const idx = list.findIndex(w => (w?.id ?? -1) === workspaceSwitcher.activeWorkspaceId);
                    selectedIndex = (idx >= 0) ? idx : 0;
                }
            } else {
                selectedIndex = 0;
            }
            clampSelection();
        } else {
            draggingWindowAddress = "";
            draggingFromWorkspaceId = -1;
            draggingTargetWorkspaceId = -1;

            frozenWorkspaceOrder = ([]);

            hoveredWorkspaceId = -1;
        }
    }

    Connections {
        target: overlay

        function onKeyPressed(key, modifiers) {
            // Right Alt is often reported as AltGr depending on layout.
            if (key === Qt.Key_Alt || key === Qt.Key_AltGr)
                workspaceSwitcher.altMode = !workspaceSwitcher.altMode;
        }
    }

    onActiveWorkspacesChanged: clampSelection()

    Component {
        id: headerComponent

        Item {
            property var win
            property var overlay
            property var ctx

            implicitWidth: titleText.implicitWidth
            implicitHeight: titleText.implicitHeight

            Text {
                id: titleText
                text: {
                    const list = workspaceSwitcher.activeWorkspaces ?? [];
                    if (!list.length)
                        return "";
                    const ws = workspaceSwitcher.hoveredWorkspace ?? workspaceSwitcher.selectedWorkspace;
                    const id = ws?.id ?? -1;
                    if (!(id > 0))
                        return "";
                    const count = SwitcherCommon.windowsInWorkspace(HyprlandData.windowList, id, Hyprland.focusedMonitor?.id)?.length ?? 0;
                    return `Workspace ${id}${count ? ` — ${count} window${count > 1 ? "s" : ""}` : ""}`;
                }
                color: Config.theme.textColor
                font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family
                font.pixelSize: 16
                elide: Text.ElideRight
                maximumLineCount: 1
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
            readonly property real panelContentW: Math.min(sw * (Config.workspaceSwitcher.panelWidthRatio ?? 0.80), (Config.workspaceSwitcher.panelMaxWidth ?? 1100))
            readonly property real tileSpacing: Math.max(0, Config.workspaceSwitcher.tileSpacing ?? 12)
            readonly property real tileMaxW: Math.min(sw * (Config.workspaceSwitcher.tileWidthRatio ?? 0.22), (Config.workspaceSwitcher.tileMaxW ?? 260))
            readonly property real tileMinW: Math.max(1, Config.workspaceSwitcher.tileMinW ?? 140)

            readonly property real workspaceAspect: {
                const mw = win ? (win.monitorWorkspaceWidth ?? 0) : 0;
                const mh = win ? (win.monitorWorkspaceHeight ?? 0) : 0;
                if (!(mw > 0) || !(mh > 0))
                    return 16 / 9;
                return mw / mh;
            }

            readonly property real tileW: Math.max(tileMinW, tileMaxW)
            readonly property real tileH: Math.round(tileW / workspaceAspect)

            // Ideal width should match the fullest row (not a single-row assumption),
            // otherwise the overlay expands to its max width when items wrap.
            readonly property int tilesPerRow: {
                const list = workspaceSwitcher.activeWorkspaces ?? [];
                const count = list?.length ?? 0;
                if (count <= 0)
                    return 1;
                const denom = tileW + tileSpacing;
                if (!(denom > 0))
                    return 1;
                const fit = Math.floor((panelContentW + tileSpacing) / denom);
                return Math.max(1, Math.min(count, fit));
            }

            readonly property real bodyIdealInnerW: {
                const list = workspaceSwitcher.activeWorkspaces ?? [];
                const count = list?.length ?? 0;
                if (count <= 0)
                    return tileW;
                const perRow = body.tilesPerRow;
                return perRow * tileW + Math.max(0, perRow - 1) * tileSpacing;
            }

            readonly property real panelInnerW: ctx ? (ctx.panelInnerW ?? panelContentW) : panelContentW

            onCtxChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = bodyIdealInnerW;
            }

            onBodyIdealInnerWChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = bodyIdealInnerW;
            }

            Component.onCompleted: {
                if (ctx)
                    ctx.bodyIdealInnerW = bodyIdealInnerW;
            }

            readonly property var tileLayout: {
                const list = workspaceSwitcher.activeWorkspaces ?? [];
                const items = [];
                for (let i = 0; i < list.length; i++) {
                    const id = list[i]?.id ?? -1;
                    items.push({
                        key: String(id),
                        w: tileW,
                        h: tileH
                    });
                }
                const result = SwitcherCommon.calculateMultiRowLayout(items, panelInnerW, tileSpacing);
                const byId = ({});
                for (const key in result.byKey) {
                    const numKey = parseInt(key);
                    if (!isNaN(numKey))
                        byId[numKey] = result.byKey[key];
                }
                return {
                    byId,
                    totalH: result.totalH
                };
            }

            implicitWidth: panelInnerW
            implicitHeight: tilesArea.implicitHeight

            Item {
                id: tilesArea
                width: body.panelInnerW
                implicitHeight: body.tileLayout.totalH

                Repeater {
                    model: workspaceSwitcher.activeWorkspaces
                    delegate: Item {
                        id: tile
                        required property var modelData
                        property var workspaceData: modelData
                        readonly property int wsId: workspaceData?.id ?? -1
                        readonly property bool selected: (workspaceSwitcher.selectedWorkspace?.id ?? -1) === wsId
                        readonly property bool hovered: workspaceSwitcher.hoveredWorkspaceId === wsId

                        readonly property real workspacePreviewScale: {
                            const mw = win ? (win.monitorWorkspaceWidth ?? 0) : 0;
                            const mh = win ? (win.monitorWorkspaceHeight ?? 0) : 0;
                            if (!(mw > 0) || !(mh > 0))
                                return 0.2;
                            return Math.min(body.tileW / mw, body.tileH / mh);
                        }

                        // --- Lift/zoom tuning ---
                        readonly property real targetScale: selected ? (Config.workspaceSwitcher.selectedScale ?? 1.045) : (hovered ? (Config.workspaceSwitcher.hoveredScale ?? 1.020) : 1.0)
                        readonly property real targetZ: selected ? (Config.workspaceSwitcher.selectedZ ?? 200) : (hovered ? (Config.workspaceSwitcher.hoveredZ ?? 120) : 0)

                        Behavior on z {
                            NumberAnimation {
                                duration: Config.workspaceSwitcher.zAnimMs ?? 90
                            }
                        }

                        x: (body.tileLayout.byId && wsId > 0 && body.tileLayout.byId[wsId]) ? body.tileLayout.byId[wsId].x : 0
                        y: (body.tileLayout.byId && wsId > 0 && body.tileLayout.byId[wsId]) ? body.tileLayout.byId[wsId].y : 0
                        width: body.tileW
                        height: body.tileH
                        z: targetZ

                        Item {
                            id: tileFx
                            anchors.fill: parent
                            transformOrigin: Item.Center
                            scale: targetScale

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.workspaceSwitcher.scaleAnimMs ?? 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            PreviewTile {
                                anchors.fill: parent
                                live: workspaceSwitcher.open
                                maskRadius: Math.max(0, Config.theme.panelRadius)
                                borderRadius: Math.max(0, Config.theme.panelRadius - 2)
                                selected: tile.selected
                                hovered: tile.hovered
                                selectedBorderColor: Config.workspaceSwitcher.selectedBorderColor ?? Config.theme.barFill
                                hoveredBorderColor: Config.workspaceSwitcher.hoveredBorderColor ?? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
                                normalBorderColor: Config.workspaceSwitcher.normalBorderColor ?? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18)
                                activeBorderWidth: Config.workspaceSwitcher.activeBorderWidth ?? 2
                                normalBorderWidth: Config.workspaceSwitcher.normalBorderWidth ?? 1

                                showWindowIcons: workspaceSwitcher.altMode

                                windowRadiusInset: Config.workspaceSwitcher.windowRadiusInset ?? 4
                                windowBorderWidth: Config.workspaceSwitcher.windowBorderWidth ?? 0.5
                                activeWindowBorderColor: Config.workspaceSwitcher.activeWindowBorderColor ?? Config.theme.barFill
                                inactiveWindowBorderColor: Config.workspaceSwitcher.inactiveWindowBorderColor ?? Config.theme.panelBg
                                windowIconMinPx: Config.workspaceSwitcher.windowIconMinPx ?? 14
                                windowIconScale: Config.workspaceSwitcher.windowIconScale ?? 0.30

                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                buildSource: true
                                sourceWidth: body.tileW
                                sourceHeight: body.tileH
                                monitorData: win ? win.monitorData : null
                                previewScale: tile.workspacePreviewScale
                                windowsModel: SwitcherCommon.windowsInWorkspace(HyprlandData.windowList, wsId, Hyprland.focusedMonitor?.id)
                                toplevelForAddress: addr => SwitcherCommon.toplevelForAddress(workspaceSwitcher.toplevels, addr)

                                highlightActiveWindow: wsId === workspaceSwitcher.activeWorkspaceId
                                activeWindowAddress: HyprlandData.activeWindow?.address ?? ""

                                wallpaperEnabled: Config.workspaceSwitcher.wallpaperEnabled ?? true
                                wallpaperSource: Config.workspaceSwitcher.wallpaperSource

                                onEntered: {
                                    if (wsId > 0)
                                        workspaceSwitcher.hoveredWorkspaceId = wsId;
                                }

                                onExited: {
                                    if (workspaceSwitcher.hoveredWorkspaceId === wsId)
                                        workspaceSwitcher.hoveredWorkspaceId = -1;
                                }

                                onClicked: {
                                    if (workspaceSwitcher.draggingWindowAddress.length)
                                        return;
                                    workspaceSwitcher.switchWorkspaceAndClose(wsId);
                                }
                            }

                            // Drop target: hovering a workspace tile while dragging a window selects it.
                            DropArea {
                                anchors.fill: parent
                                enabled: (Config.workspaceSwitcher.enableWindowDrag ?? true) && workspaceSwitcher.draggingWindowAddress.length > 0

                                onEntered: {
                                    if (wsId > 0)
                                        workspaceSwitcher.draggingTargetWorkspaceId = wsId;
                                }

                                onExited: {
                                    if (workspaceSwitcher.draggingTargetWorkspaceId === wsId)
                                        workspaceSwitcher.draggingTargetWorkspaceId = -1;
                                }
                            }

                            // Drag sources: invisible hitboxes over each window preview.
                            Item {
                                id: windowDragOverlay
                                anchors.fill: parent
                                z: 5
                                visible: Config.workspaceSwitcher.enableWindowDrag ?? true

                                Repeater {
                                    model: SwitcherCommon.windowsInWorkspace(HyprlandData.windowList, wsId, Hyprland.focusedMonitor?.id)
                                    delegate: Item {
                                        id: windowHitbox
                                        required property var modelData
                                        property var windowData: modelData

                                        readonly property string windowAddress: (typeof windowData?.address === "string") ? windowData.address : ""
                                        readonly property real baseX: Math.round(SwitcherCommon.windowLocalX(windowData, win ? win.monitorData : null) * tile.workspacePreviewScale)
                                        readonly property real baseY: Math.round(SwitcherCommon.windowLocalY(windowData, win ? win.monitorData : null) * tile.workspacePreviewScale)
                                        readonly property real baseW: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * tile.workspacePreviewScale))
                                        readonly property real baseH: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * tile.workspacePreviewScale))

                                        property bool dndActive: false

                                        x: baseX
                                        y: baseY
                                        width: baseW
                                        height: baseH
                                        visible: workspaceSwitcher.open && windowAddress.length > 0

                                        Drag.active: dndActive
                                        Drag.source: windowHitbox
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: windowHitbox.dndActive
                                            color: "transparent"
                                            radius: Math.max(0, Config.theme.panelRadius - 6)
                                            border.width: 2
                                            border.color: Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.85)
                                            antialiasing: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            propagateComposedEvents: true
                                            drag.target: windowHitbox
                                            drag.axis: Drag.XAndYAxis
                                            drag.threshold: Config.workspaceSwitcher.dragThresholdPx ?? 10

                                            onPressed: mouse => {
                                                windowHitbox.dndActive = false;
                                            }

                                            onPositionChanged: mouse => {
                                                if (drag.active && !windowHitbox.dndActive) {
                                                    windowHitbox.dndActive = true;
                                                    workspaceSwitcher.draggingWindowAddress = windowHitbox.windowAddress;
                                                    workspaceSwitcher.draggingFromWorkspaceId = wsId;
                                                    workspaceSwitcher.draggingTargetWorkspaceId = -1;
                                                }
                                            }

                                            onReleased: mouse => {
                                                if (windowHitbox.dndActive) {
                                                    const addr = workspaceSwitcher.draggingWindowAddress;
                                                    const fromWs = workspaceSwitcher.draggingFromWorkspaceId;
                                                    const targetWs = workspaceSwitcher.draggingTargetWorkspaceId;

                                                    workspaceSwitcher.draggingWindowAddress = "";
                                                    workspaceSwitcher.draggingFromWorkspaceId = -1;
                                                    workspaceSwitcher.draggingTargetWorkspaceId = -1;
                                                    windowHitbox.dndActive = false;

                                                    // Reset hitbox position (we only use the movement to initiate drag)
                                                    windowHitbox.x = windowHitbox.baseX;
                                                    windowHitbox.y = windowHitbox.baseY;

                                                    if (targetWs > 0 && targetWs !== fromWs && addr.length)
                                                        SwitcherCommon.dispatchMoveWindowToWorkspace(Hyprland, targetWs, addr, true);

                                                    mouse.accepted = true;
                                                    return;
                                                }

                                                // Not a drag: reset any movement and allow normal click-to-switch.
                                                windowHitbox.x = windowHitbox.baseX;
                                                windowHitbox.y = windowHitbox.baseY;
                                                mouse.accepted = false;
                                            }

                                            onClicked: mouse => {
                                                // Let the underlying PreviewTile handle click-to-switch.
                                                mouse.accepted = false;
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: wsLabel
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 8
                                visible: (Config.workspaceSwitcher.showWorkspaceNumberInAltMode ?? true) && workspaceSwitcher.altMode
                                z: 10

                                readonly property int padX: Config.workspaceSwitcher.workspaceLabelPadX ?? 7
                                readonly property int padY: Config.workspaceSwitcher.workspaceLabelPadY ?? 4
                                implicitWidth: labelText.implicitWidth + padX * 2
                                implicitHeight: labelText.implicitHeight + padY * 2

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.max(0, Config.theme.panelRadius - 6)
                                    color: Qt.rgba(Config.theme.panelBg.r, Config.theme.panelBg.g, Config.theme.panelBg.b, Config.workspaceSwitcher.workspaceLabelBgAlpha ?? 0.70)
                                    border.width: 1
                                    border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, Config.workspaceSwitcher.workspaceLabelBorderAlpha ?? 0.20)
                                    antialiasing: true
                                }

                                Text {
                                    id: labelText
                                    anchors.centerIn: parent
                                    text: `${wsId}`
                                    color: Config.theme.textColor
                                    font.pixelSize: Config.workspaceSwitcher.workspaceLabelFontSize ?? 14
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

        open: workspaceSwitcher.open
        focusedOnly: true
        namespace: "quickshell:workspace_switcher"

        closeOnModifierRelease: true
        modifierMask: Qt.MetaModifier

        panelPadding: Config.workspaceSwitcher.panelPadding ?? 14
        sectionSpacing: Config.workspaceSwitcher.sectionSpacing ?? 10
        panelWidthRatio: Config.workspaceSwitcher.panelWidthRatio ?? 0.80
        panelMaxWidth: Config.workspaceSwitcher.panelMaxWidth ?? 1100
        showSeparator: false

        header: null
        body: bodyComponent

        onCancelRequested: {
            workspaceSwitcher.open = false;
        }

        onCommitRequested: {
            workspaceSwitcher.commitSelectionAndClose();
        }
    }

    IpcHandler {
        target: "workspace_switcher"

        function isActive(): bool {
            return workspaceSwitcher.open;
        }

        function toggle() {
            workspaceSwitcher.open = !workspaceSwitcher.open;
        }

        function open() {
            HyprlandData.updateAll();
            workspaceSwitcher.open = true;
        }

        function close() {
            workspaceSwitcher.commitSelectionAndClose();
        }

        function next() {
            if (!workspaceSwitcher.open) {
                HyprlandData.updateAll();
                workspaceSwitcher.open = true;

                // `onOpenChanged` sets the initial selection.
                // Optionally advance once (classic Alt-Tab behavior).
                if (Config.workspaceSwitcher.cycleAdvanceOnOpen ?? true)
                    workspaceSwitcher.selectNext();
                return;
            }
            workspaceSwitcher.selectNext();
        }

        function prev() {
            if (!workspaceSwitcher.open) {
                HyprlandData.updateAll();
                workspaceSwitcher.open = true;

                if (Config.workspaceSwitcher.cycleAdvanceOnOpen ?? true)
                    workspaceSwitcher.selectPrev();
                return;
            }
            workspaceSwitcher.selectPrev();
        }
    }
}
