import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import "../config"
import "../services"

Scope {
    id: launcher

    // Public state
    property bool open: false
    property bool focusedOnly: true
    property string query: ""

    // Desktop indexer results (rendered later)
    property var availableApps: []
    property bool searching: false
    property string searchError: ""

    // Enable with: QS_LAUNCHER_DEBUG=1 qs
    property bool debug: {
        const v = (Quickshell.env("QS_LAUNCHER_DEBUG") || "").toLowerCase();
        return v === "1" || v === "true" || v === "yes";
    }

    function _log(section, text) {
        if (!launcher.debug)
            return;
        const s = (text ?? "").toString().trim();
        console.log(`[launcher][${section}] ${s.length ? s : "(empty)"}`);
    }

    function _appLabel(app) {
        if (!app)
            return "";
        return (app.name ?? app.display_name ?? app.displayName ?? app.app_id ?? app.appId ?? app.id ?? app.exec ?? "").toString();
    }

    function _appSubtitle(app) {
        if (!app)
            return "";
        return (app.exec ?? app.command ?? app.path ?? app.desktop_file ?? app.desktopFile ?? "").toString();
    }

    function _desktopId(app) {
        if (!app)
            return "";
        if (typeof app === "string")
            return app;
        // Try common field names from desktop-indexer / desktop entries.
        return (app.desktop_id ?? app.desktopId ?? app.desktop_file ?? app.desktopFile ?? app.id ?? app.app_id ?? app.appId ?? "").toString();
    }

    function _asStringList(value) {
        if (!value)
            return "";
        if (typeof value === "string")
            return value;
        if (Array.isArray(value))
            return value.map(v => (v ?? "").toString()).filter(s => s.length).join(", ");
        if (typeof value.length === "number") {
            // array-like (e.g. QVariantList)
            const parts = [];
            for (let i = 0; i < value.length; i++) {
                const s = (value[i] ?? "").toString();
                if (s.length)
                    parts.push(s);
            }
            return parts.join(", ");
        }
        return value.toString();
    }

    function _menuModelForApp(app) {
        const items = [];
        items.push({
            kind: "action",
            text: "Launch",
            actionId: ""
        });

        if (app && typeof app !== "string") {
            const rawActs = app.actions ?? app.desktop_actions ?? app.desktopActions ?? app.desktopActionsList ?? [];
            const acts = [];

            if (Array.isArray(rawActs)) {
                for (let i = 0; i < rawActs.length; i++)
                    acts.push(rawActs[i]);
            } else if (rawActs && typeof rawActs.length === "number") {
                for (let i = 0; i < rawActs.length; i++)
                    acts.push(rawActs[i]);
            }

            for (let i = 0; i < acts.length; i++) {
                const a = acts[i] ?? {};
                items.push({
                    kind: "action",
                    text: (a.name ?? a.id ?? "Action").toString(),
                    actionId: (a.id ?? "").toString()
                });
            }
        }

        items.push({
            kind: "action",
            text: "Properties",
            actionId: "__properties__"
        });

        return items;
    }

    function _propertiesModelForApp(app) {
        const items = [];
        items.push({
            kind: "action",
            text: "Back",
            actionId: "__back__"
        });

        if (!app || typeof app === "string")
            return items;

        const name = (app.name ?? app.display_name ?? app.displayName ?? "").toString();
        if (name.length)
            items.push({
                kind: "info",
                text: `Name: ${name}`
            });

        const comment = (app.comment ?? app.description ?? app.generic_name ?? app.genericName ?? "").toString();
        if (comment.length)
            items.push({
                kind: "info",
                text: `Comment: ${comment}`
            });

        const did = launcher._desktopId(app);
        if (did.length)
            items.push({
                kind: "info",
                text: `ID: ${did}`
            });

        const ex = (app.exec ?? app.command ?? "").toString();
        if (ex.length)
            items.push({
                kind: "info",
                text: `Exec: ${ex}`
            });

        const desktopFile = (app.desktop_file ?? app.desktopFile ?? app.path ?? "").toString();
        if (desktopFile.length)
            items.push({
                kind: "info",
                text: `Desktop file: ${desktopFile}`
            });

        const icon = (app.icon ?? app.icon_name ?? app.iconName ?? "").toString();
        if (icon.length)
            items.push({
                kind: "info",
                text: `Icon: ${icon}`
            });

        const tryExec = (app.try_exec ?? app.tryExec ?? "").toString();
        if (tryExec.length)
            items.push({
                kind: "info",
                text: `TryExec: ${tryExec}`
            });

        const wmClass = (app.startup_wm_class ?? app.startupWmClass ?? app.wm_class ?? app.wmClass ?? "").toString();
        if (wmClass.length)
            items.push({
                kind: "info",
                text: `WM class: ${wmClass}`
            });

        const categories = launcher._asStringList(app.categories ?? app.category ?? "");
        if (categories.length)
            items.push({
                kind: "info",
                text: `Categories: ${categories}`
            });

        const keywords = launcher._asStringList(app.keywords ?? app.keyword ?? "");
        if (keywords.length)
            items.push({
                kind: "info",
                text: `Keywords: ${keywords}`
            });

        return items;
    }

    function _resultsLabel(count) {
        return count === 1 ? "1 result" : `${count} results`;
    }

    property int selectedIndex: -1

    property bool launching: false
    property string launchError: ""

    function _clampSelected() {
        const n = launcher.availableApps?.length ?? 0;
        if (n <= 0) {
            launcher.selectedIndex = -1;
            return;
        }
        if (launcher.selectedIndex < 0)
            return;
        if (launcher.selectedIndex >= n)
            launcher.selectedIndex = n - 1;
    }

    function selectNext() {
        const n = launcher.availableApps?.length ?? 0;
        if (n <= 0)
            return;
        launcher.selectedIndex = Math.min(n - 1, Math.max(0, launcher.selectedIndex + 1));
    }

    function selectPrev() {
        const n = launcher.availableApps?.length ?? 0;
        if (n <= 0)
            return;
        if (launcher.selectedIndex < 0)
            launcher.selectedIndex = 0;
        else
            launcher.selectedIndex = Math.max(0, launcher.selectedIndex - 1);
    }

    function launchApp(app, action) {
        if (!launcher.open)
            return;

        const desktopId = launcher._desktopId(app);
        launcher.launchError = "";

        if (!desktopId.length) {
            launcher.launchError = "Missing DESKTOP_ID for selected app";
            launcher._log("launch", launcher.launchError);
            return;
        }

        const cmd = ["desktop-indexer", "launch", desktopId];
        if (action !== undefined && action !== null && ("" + action).length)
            cmd.push("--action", ("" + action));

        launcher._log("launch", `cmd=${JSON.stringify(cmd)}`);

        launcher.launching = true;
        launchProc.command = cmd;
        if (launchProc.running)
            launchProc.running = false;
        launchProc.running = true;

        // Close immediately like a classic launcher.
        launcher.close();
    }

    function launchSelected() {
        const n = launcher.availableApps?.length ?? 0;
        if (n <= 0)
            return;
        const idx = launcher.selectedIndex < 0 ? 0 : launcher.selectedIndex;
        const app = launcher.availableApps[idx];
        launcher.launchApp(app, undefined);
    }

    // Used to push externally-provided query strings into the input
    property int queryRevision: 0

    function setQueryExternal(text) {
        launcher.query = (text ?? "").toString();
        launcher.queryRevision++;
    }

    function openWithQuery(text) {
        if (text !== undefined)
            launcher.setQueryExternal(text);
        launcher.open = true;
    }

    function close() {
        launcher.open = false;

        // Reset to base state so reopening starts clean.
        launcher.query = "";
        launcher.queryRevision++;
        launcher.availableApps = [];
        launcher.selectedIndex = -1;
        launcher.searching = false;
        launcher.searchError = "";

        searchDebounce.stop();
        if (searchProc.running)
            searchProc.running = false;
    }

    function toggle(text) {
        if (!launcher.open) {
            launcher.openWithQuery(text);
        } else {
            launcher.close();
        }
    }

    function _effectiveEmptyMode() {
        const v = (Config.launcher?.emptyMode ?? "recency").toString().toLowerCase();
        return (v === "frequency") ? "frequency" : "recency";
    }

    function scheduleSearch() {
        if (!launcher.open)
            return;
        searchDebounce.restart();
    }

    function runSearchNow() {
        if (!launcher.open)
            return;

        const q = (launcher.query ?? "").toString();
        const emptyMode = launcher._effectiveEmptyMode();

        launcher._log("search", `run: query=${JSON.stringify(q)} emptyMode=${emptyMode}`);

        launcher.searching = true;
        launcher.searchError = "";
        launcher.launchError = "";

        // Reset selection so Enter makes sense for the new query.
        launcher.selectedIndex = 0;

        searchProc.command = ["desktop-indexer", "search", q, "--json", "--empty-mode", emptyMode];

        if (searchProc.running)
            searchProc.running = false;
        searchProc.running = true;
    }

    Timer {
        id: searchDebounce
        interval: 50
        repeat: false
        onTriggered: launcher.runSearchNow()
    }

    Process {
        id: searchProc
        running: false

        onExited: () => {
            launcher.searching = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                launcher.searching = false;
                const raw = (this.text ?? "").toString().trim();
                if (!raw.length) {
                    launcher.availableApps = [];
                    launcher.selectedIndex = -1;
                    launcher._log("search", "stdout empty -> 0 results");
                    return;
                }
                try {
                    const parsed = JSON.parse(raw);
                    launcher.availableApps = Array.isArray(parsed) ? parsed : (parsed?.items ?? []);
                    launcher.selectedIndex = launcher.availableApps.length > 0 ? 0 : -1;
                    launcher._log("search", `parsed ${launcher.availableApps.length} results`);
                } catch (e) {
                    launcher.availableApps = [];
                    launcher.selectedIndex = -1;
                    launcher.searchError = `Invalid JSON from desktop-indexer: ${e}`;
                    launcher._log("search", launcher.searchError);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length) {
                    launcher.searchError = s;
                    launcher._log("search stderr", s);
                }
            }
        }
    }

    Process {
        id: launchProc
        running: false

        onExited: () => {
            launcher.launching = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length)
                    launcher._log("launch stdout", s);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length) {
                    launcher.launchError = s;
                    launcher._log("launch stderr", s);
                }
            }
        }
    }

    Variants {
        id: variants
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
            readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

            // Animation driver: keeps window alive while closing.
            property real shown: launcher.open ? 1.0 : 0.0
            Behavior on shown {
                NumberAnimation {
                    duration: launcher.open ? 180 : 140
                    easing.type: launcher.open ? Easing.OutCubic : Easing.InCubic
                }
            }

            visible: shown > 0.001 && (!launcher.focusedOnly || monitorIsFocused)
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: launcher.open && monitorIsFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                left: true
                top: true
                right: true
                bottom: true
            }

            readonly property var scr: win.screen
            readonly property real sw: scr ? scr.width : 0
            readonly property real sh: scr ? scr.height : 0

            // Windows-like launcher panel: fixed-ish size, clamped to screen.
            readonly property real idealW: Math.min(720, Math.max(520, sw - 60))
            readonly property real idealH: Math.min(560, Math.max(420, sh - 120))

            // Slide in from below (like OsdWindow's margin interpolation).
            readonly property real visibleBottomMargin: 32
            readonly property real hiddenBottomMargin: -(idealH + 24)

            HyprlandFocusGrab {
                id: grab
                windows: [win]
                active: launcher.open && win.monitorIsFocused
                onCleared: () => {
                    if (!active)
                        launcher.close();
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                visible: win.visible
                focus: visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (ctx.visible) {
                            if (ctx.page === "properties") {
                                ctx.page = "main";
                                ctx._setItems(launcher._menuModelForApp(ctx.app));
                            } else {
                                ctx.close();
                            }
                        } else {
                            launcher.close();
                        }
                        event.accepted = true;
                        return;
                    }
                }

                // Click outside the panel closes the launcher.
                MouseArea {
                    id: outsideClick
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    propagateComposedEvents: true
                    onPressed: mouse => {
                        const p = panelContainer.mapFromItem(outsideClick, mouse.x, mouse.y);
                        const inside = p.x >= 0 && p.y >= 0 && p.x <= panelContainer.width && p.y <= panelContainer.height;
                        if (!inside)
                            launcher.close();
                        mouse.accepted = false;
                    }
                }

                Item {
                    id: panelContainer
                    width: win.idealW
                    height: win.idealH
                    x: Math.max(0, (win.sw - width) / 2)
                    y: win.sh - height - (win.visibleBottomMargin * win.shown + win.hiddenBottomMargin * (1.0 - win.shown))

                    Item {
                        id: animWrap
                        anchors.fill: parent
                        opacity: win.shown

                        readonly property real slidePx: 44
                        readonly property real s: 0.96 + 0.04 * win.shown

                        transform: [
                            Translate {
                                y: (1.0 - win.shown) * animWrap.slidePx
                            },
                            Scale {
                                origin.x: animWrap.width / 2
                                origin.y: animWrap.height / 2
                                xScale: animWrap.s
                                yScale: animWrap.s
                            }
                        ]

                        Rectangle {
                            id: frame
                            anchors.fill: parent
                            radius: Config.theme.panelRadius
                            color: Config.theme.panelBg
                            border.width: 1
                            border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.20)

                            // Click anywhere outside the context menu to close it.
                            // This sits above normal content but below the menu itself.
                            MouseArea {
                                id: ctxDismiss
                                anchors.fill: parent
                                z: 998
                                visible: ctx.visible
                                enabled: ctx.visible
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                propagateComposedEvents: true
                                onPressed: mouse => {
                                    // If the click is inside the menu box, let it through.
                                    const p = menuBox.mapFromItem(ctxDismiss, mouse.x, mouse.y);
                                    const inside = p.x >= 0 && p.y >= 0 && p.x <= menuBox.width && p.y <= menuBox.height;
                                    if (!inside)
                                        ctx.close();
                                    mouse.accepted = false;
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                // Search bar (top)
                                Item {
                                    width: parent.width
                                    height: 46

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                                    }

                                    Rectangle {
                                        x: 10
                                        y: 8
                                        width: 30
                                        height: 30
                                        radius: 10
                                        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                                        border.width: 1
                                        border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.12)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⌕"
                                            color: Config.theme.textColor
                                            font.pixelSize: 16
                                        }
                                    }

                                    Item {
                                        id: inputWrap
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 46
                                        anchors.rightMargin: 12
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom

                                        property bool syncing: false

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Search…"
                                            color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.45)
                                            font.pixelSize: 15
                                            visible: searchInput.text.length === 0
                                        }

                                        TextInput {
                                            id: searchInput
                                            anchors.left: parent.left
                                            anchors.right: statusWrap.left
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: parent.height
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: Config.theme.textColor
                                            selectionColor: Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.35)
                                            selectedTextColor: Config.theme.textColor
                                            font.pixelSize: 16

                                            onTextChanged: {
                                                if (inputWrap.syncing)
                                                    return;
                                                launcher.query = text;
                                                launcher.selectedIndex = 0;
                                                launcher.scheduleSearch();
                                            }

                                            Keys.onPressed: event => {
                                                if (event.key === Qt.Key_Escape) {
                                                    if (ctx.visible) {
                                                        if (ctx.page === "properties") {
                                                            ctx.page = "main";
                                                            ctx._setItems(launcher._menuModelForApp(ctx.app));
                                                        } else {
                                                            ctx.close();
                                                        }
                                                    } else {
                                                        launcher.close();
                                                    }
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
                                                    launcher.selectPrev();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Backtab) {
                                                    launcher.selectPrev();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Tab) {
                                                    launcher.selectNext();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Down) {
                                                    launcher.selectNext();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Up) {
                                                    launcher.selectPrev();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                    launcher.launchSelected();
                                                    event.accepted = true;
                                                    return;
                                                }
                                            }
                                        }

                                        Item {
                                            id: statusWrap
                                            anchors.right: parent.right
                                            width: 150
                                            height: parent.height

                                            Text {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: launcher.searching ? "Searching…" : launcher._resultsLabel(launcher.availableApps.length)
                                                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.60)
                                                font.pixelSize: 12
                                            }
                                        }

                                        Connections {
                                            target: launcher

                                            function onOpenChanged() {
                                                if (!launcher.open) {
                                                    ctx.close();
                                                    return;
                                                }
                                                if (!win.monitorIsFocused)
                                                    return;
                                                Qt.callLater(() => {
                                                    inputWrap.syncing = true;
                                                    searchInput.text = launcher.query;
                                                    searchInput.cursorPosition = searchInput.text.length;
                                                    inputWrap.syncing = false;
                                                    searchInput.forceActiveFocus();
                                                });

                                                launcher.selectedIndex = 0;
                                                launcher.scheduleSearch();
                                            }

                                            function onQueryRevisionChanged() {
                                                if (!launcher.open)
                                                    return;
                                                if (!win.monitorIsFocused)
                                                    return;
                                                Qt.callLater(() => {
                                                    inputWrap.syncing = true;
                                                    searchInput.text = launcher.query;
                                                    searchInput.cursorPosition = searchInput.text.length;
                                                    inputWrap.syncing = false;
                                                    searchInput.forceActiveFocus();
                                                });
                                            }
                                        }
                                    }
                                }

                                // Error strip (if any)
                                Rectangle {
                                    width: parent.width
                                    height: launcher.searchError.length > 0 ? 28 : 0
                                    radius: 10
                                    visible: launcher.searchError.length > 0
                                    color: Qt.rgba(0.85, 0.25, 0.25, 0.18)
                                    border.width: 1
                                    border.color: Qt.rgba(0.85, 0.25, 0.25, 0.28)

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: launcher.searchError
                                        color: Qt.rgba(1, 1, 1, 0.85)
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                // Results list
                                Rectangle {
                                    id: resultsFrame
                                    width: parent.width
                                    height: parent.height - 46 - (launcher.searchError.length > 0 ? 28 : 0) - 12
                                    radius: 16
                                    color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
                                    clip: true

                                    // One context menu overlay for the whole list.
                                    Item {
                                        id: ctx
                                        anchors.fill: parent
                                        visible: false
                                        z: 999

                                        property var app: null
                                        property var items: []
                                        property string page: "main"

                                        readonly property int pad: 6
                                        readonly property int rowH: 30
                                        readonly property int rowSpacing: 2
                                        readonly property int menuW: 360

                                        property real _pendingSceneX: 0
                                        property real _pendingSceneY: 0

                                        function close() {
                                            ctx.visible = false;
                                            ctx.app = null;
                                            ctx.items = [];
                                            ctx.page = "main";
                                        }

                                        function _setItems(newItems) {
                                            ctx.items = newItems ?? [];
                                            Qt.callLater(() => {
                                                if (!ctx.visible)
                                                    return;
                                                ctx._reposition();
                                            });
                                        }

                                        function _launchFromMenu(appObj, action) {
                                            launcher.launchApp(appObj, action);
                                        }

                                        function openAtScene(sceneX, sceneY, appObj) {
                                            ctx.app = appObj;
                                            ctx.page = "main";
                                            ctx._setItems(launcher._menuModelForApp(appObj));

                                            if (launcher.debug) {
                                                let actionRows = 0;
                                                for (let i = 0; i < (ctx.items?.length ?? 0); i++) {
                                                    if ((ctx.items[i]?.kind ?? "") === "action")
                                                        actionRows++;
                                                }
                                                const extraActions = Math.max(0, actionRows - 1); // minus the default "Launch"
                                                launcher._log("ctx", `open for ${launcher._appLabel(appObj)} actions=${extraActions} items=${ctx.items?.length ?? 0}`);
                                            }

                                            ctx._pendingSceneX = sceneX;
                                            ctx._pendingSceneY = sceneY;
                                            ctx.visible = true;
                                        }

                                        function _reposition() {
                                            const p = resultsFrame.mapFromItem(null, ctx._pendingSceneX, ctx._pendingSceneY);
                                            let x = (p && p.x !== undefined) ? p.x : 0;
                                            let y = (p && p.y !== undefined) ? p.y : 0;

                                            const margin = 6;
                                            const mw = menuBox.width;
                                            const mh = menuBox.height;

                                            // Flip if overflowing
                                            if (x + mw + margin > resultsFrame.width)
                                                x = x - mw;
                                            if (y + mh + margin > resultsFrame.height)
                                                y = y - mh;

                                            // Clamp
                                            x = Math.max(margin, Math.min(x, resultsFrame.width - mw - margin));
                                            y = Math.max(margin, Math.min(y, resultsFrame.height - mh - margin));

                                            menuBox.x = x;
                                            menuBox.y = y;
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onPressed: ctx.close()
                                        }

                                        Rectangle {
                                            id: menuBox
                                            width: ctx.menuW + ctx.pad * 2
                                            height: menuContent.implicitHeight + ctx.pad * 2
                                            radius: 12
                                            color: Config.theme.panelBg
                                            border.width: 1
                                            border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.16)

                                            Column {
                                                id: menuContent
                                                anchors.fill: parent
                                                anchors.margins: ctx.pad
                                                spacing: ctx.rowSpacing

                                                Repeater {
                                                    model: ctx.items

                                                    delegate: Item {
                                                        required property var modelData

                                                        width: ctx.menuW
                                                        height: ctx.rowH

                                                        property bool hovered: false
                                                        readonly property bool isAction: (modelData?.kind ?? "") === "action"

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            radius: 8
                                                            color: (hovered && isAction) ? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.08) : "transparent"
                                                        }

                                                        Text {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: 10
                                                            anchors.right: parent.right
                                                            anchors.rightMargin: 10
                                                            text: (modelData?.text ?? "").toString()
                                                            elide: Text.ElideRight
                                                            color: isAction ? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.92) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.60)
                                                            font.pixelSize: 13
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            enabled: isAction
                                                            onEntered: parent.hovered = true
                                                            onExited: parent.hovered = false
                                                            onClicked: {
                                                                const actionId = (modelData?.actionId ?? "").toString();
                                                                // Delegate scopes can lack access to outer ids; walk parents.
                                                                // MouseArea -> delegate Item -> menuContent -> menuBox -> ctx
                                                                const ctxItem = parent.parent.parent.parent;
                                                                const appObj = ctxItem.app;

                                                                if (actionId === "__properties__") {
                                                                    ctxItem.page = "properties";
                                                                    ctxItem._setItems(launcher._propertiesModelForApp(appObj));
                                                                    return;
                                                                }
                                                                if (actionId === "__back__") {
                                                                    ctxItem.page = "main";
                                                                    ctxItem._setItems(launcher._menuModelForApp(appObj));
                                                                    return;
                                                                }

                                                                const action = actionId.length ? actionId : undefined;
                                                                ctxItem.close();
                                                                ctxItem._launchFromMenu(appObj, action);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    AppList {
                                        anchors.fill: parent
                                        apps: launcher.availableApps
                                        searching: launcher.searching
                                        query: launcher.query
                                        searchError: launcher.searchError
                                        selectedIndex: launcher.selectedIndex

                                        onRequestSelect: (index, app) => {
                                            launcher.selectedIndex = index;
                                            ctx.close();
                                        }

                                        onRequestActivate: (index, app, actionId) => {
                                            launcher.selectedIndex = index;
                                            launcher.launchApp(app, actionId);
                                        }

                                        onRequestContextMenu: (index, app, sx, sy) => {
                                            launcher.selectedIndex = index;
                                            ctx.openAtScene(sx, sy, app);
                                        }
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
        target: "launcher"

        function isActive(): bool {
            return launcher.open;
        }

        function toggle() {
            launcher.toggle();
        }

        function toggleWithQuery(text: string) {
            launcher.toggle(text);
        }

        function open() {
            launcher.openWithQuery(undefined);
        }

        function openWithQuery(text: string) {
            launcher.openWithQuery(text);
        }

        function close() {
            launcher.close();
        }

        function setQuery(text: string) {
            launcher.setQueryExternal(text);
        }
    }
}
