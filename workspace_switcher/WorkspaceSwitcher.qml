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

    readonly property var activeWorkspaces: {
        return SwitcherCommon.calculateActiveWorkspaces(HyprlandData.workspaces, HyprlandData.windowList, workspaceSwitcher.activeWorkspaceId, Hyprland.focusedMonitor?.id);
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
            hoveredWorkspaceId = -1;
            selectedIndex = 0;
            clampSelection();
        } else {
            hoveredWorkspaceId = -1;
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
            readonly property real panelContentW: Math.min(sw * 0.80, 1100)
            readonly property real tileSpacing: 12
            readonly property real tileMaxW: Math.min(sw * 0.22, 260)
            readonly property real tileMinW: 140

            readonly property real workspaceAspect: {
                const mw = win ? (win.monitorWorkspaceWidth ?? 0) : 0;
                const mh = win ? (win.monitorWorkspaceHeight ?? 0) : 0;
                if (!(mw > 0) || !(mh > 0))
                    return 16 / 9;
                return mw / mh;
            }

            readonly property real tileW: Math.max(tileMinW, tileMaxW)
            readonly property real tileH: Math.round(tileW / workspaceAspect)

            readonly property real tileIdealInnerW: {
                const list = workspaceSwitcher.activeWorkspaces ?? [];
                if (!list || list.length === 0)
                    return tileW;
                return list.length * tileW + Math.max(0, list.length - 1) * tileSpacing;
            }

            readonly property real panelInnerW: ctx ? (ctx.panelInnerW ?? panelContentW) : panelContentW

            onCtxChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = tileIdealInnerW;
            }

            onTileIdealInnerWChanged: {
                if (ctx)
                    ctx.bodyIdealInnerW = tileIdealInnerW;
            }

            Component.onCompleted: {
                if (ctx)
                    ctx.bodyIdealInnerW = tileIdealInnerW;
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
                        readonly property real targetScale: selected ? 1.045 : (hovered ? 1.020 : 1.0)
                        readonly property real targetZ: selected ? 200 : (hovered ? 120 : 0)

                        Behavior on z {
                            NumberAnimation {
                                duration: 90
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
                                    duration: 120
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
                                selectedBorderColor: Config.theme.barFill
                                hoveredBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
                                normalBorderColor: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18)
                                activeBorderWidth: 2
                                normalBorderWidth: 1

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

                                wallpaperEnabled: true
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
                                    workspaceSwitcher.switchWorkspaceAndClose(wsId);
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 8
                                text: `${wsId}`
                                color: Config.theme.textColor
                                font.pixelSize: 14
                                z: 10
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

        panelPadding: 14
        sectionSpacing: 10
        showSeparator: true

        header: headerComponent
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

                // Active workspace = index 0, so first Super+Tab should go to index 1
                workspaceSwitcher.selectedIndex = 0;
                workspaceSwitcher.clampSelection();
            }
            workspaceSwitcher.selectNext();
        }

        function prev() {
            if (!workspaceSwitcher.open) {
                HyprlandData.updateAll();
                workspaceSwitcher.open = true;
                workspaceSwitcher.selectedIndex = 0;
                workspaceSwitcher.clampSelection();
            }
            workspaceSwitcher.selectPrev();
        }
    }
}
