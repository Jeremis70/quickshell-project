pragma Singleton

import QtQuick
import Quickshell.Hyprland

QtObject {
    // --- Workspace switcher helpers (generic, dependency-injected) ---
    function toplevelForAddress(toplevels, address) {
        if (!address || typeof address !== "string")
            return null;
        const values = toplevels?.values;
        if (!values || !values.length)
            return null;
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            const a = t?.HyprlandToplevel?.address;
            if (!a)
                continue;
            const full = `0x${a}`;
            if (full === address)
                return t;
        }
        return null;
    }

    function windowsInWorkspace(windowList, wsId, focusedMonitorId) {
        if (!(wsId > 0))
            return [];
        const windows = windowList ?? [];
        return windows.filter(w => (w?.workspace?.id ?? -1) === wsId).filter(w => (typeof focusedMonitorId === "number") ? (w?.monitor === focusedMonitorId) : true);
    }

    function workspaceRecency(windowList, wsId, focusedMonitorId) {
        const list = SwitcherCommon.windowsInWorkspace(windowList, wsId, focusedMonitorId);
        if (!list || list.length === 0)
            return Number.MAX_SAFE_INTEGER;
        let minId = Number.MAX_SAFE_INTEGER;
        for (let i = 0; i < list.length; i++) {
            const fh = list[i]?.focusHistoryID;
            const v = (typeof fh === "number") ? fh : Number.MAX_SAFE_INTEGER;
            if (v < minId)
                minId = v;
        }
        return minId;
    }

    function dispatchSwitchWorkspace(hyprland, activeWorkspaceId, wsId) {
        if (!(wsId > 0))
            return;
        // If Hyprland has workspace_back_and_forth enabled, dispatching the current
        // workspace ID toggles to the previous workspace and can error if none exists.
        if (wsId === activeWorkspaceId)
            return;
        hyprland?.dispatch?.(`workspace ${wsId}`);
    }

    // Returns the visible workspaces in the same order as WorkspaceSwitcher used to.
    function calculateActiveWorkspaces(workspaces, windowList, activeWorkspaceId, focusedMonitorId) {
        const wsList = workspaces ?? [];
        const windows = windowList ?? [];

        const counts = ({});
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            const wid = w?.workspace?.id ?? -1;
            if (!(wid > 0))
                continue;
            if (typeof focusedMonitorId === "number" && w?.monitor !== focusedMonitorId)
                continue;
            counts[wid] = (counts[wid] ?? 0) + 1;
        }

        let list = [];
        for (let i = 0; i < wsList.length; i++) {
            const ws = wsList[i];
            const id = ws?.id ?? -1;
            if (!(id > 0))
                continue;
            const hasWindows = (counts[id] ?? 0) > 0;
            if (hasWindows || id === activeWorkspaceId)
                list.push(ws);
        }

        list.sort((a, b) => {
            const wa = a?.id ?? -1;
            const wb = b?.id ?? -1;
            const ra = SwitcherCommon.workspaceRecency(windows, wa, focusedMonitorId);
            const rb = SwitcherCommon.workspaceRecency(windows, wb, focusedMonitorId);
            if (ra !== rb)
                return ra - rb;
            return wa - wb;
        });

        if (activeWorkspaceId > 0) {
            const idx = list.findIndex(w => (w?.id ?? -1) === activeWorkspaceId);
            if (idx > 0)
                list = list.slice(idx).concat(list.slice(0, idx));
        }

        return list;
    }

    // Returns the visible workspaces in numeric id order (no MRU rotation).
    function calculateActiveWorkspacesOrdered(workspaces, windowList, activeWorkspaceId, focusedMonitorId) {
        const wsList = workspaces ?? [];
        const windows = windowList ?? [];

        const counts = ({});
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            const wid = w?.workspace?.id ?? -1;
            if (!(wid > 0))
                continue;
            if (typeof focusedMonitorId === "number" && w?.monitor !== focusedMonitorId)
                continue;
            counts[wid] = (counts[wid] ?? 0) + 1;
        }

        let list = [];
        for (let i = 0; i < wsList.length; i++) {
            const ws = wsList[i];
            const id = ws?.id ?? -1;
            if (!(id > 0))
                continue;
            const hasWindows = (counts[id] ?? 0) > 0;
            if (hasWindows || id === activeWorkspaceId)
                list.push(ws);
        }

        list.sort((a, b) => (a?.id ?? 0) - (b?.id ?? 0));
        return list;
    }

    // Returns windows for the active workspace, filtered to focused monitor (if provided),
    // sorted by focus history, then rotated so active window is index 0.
    function calculateWindowsInActiveWorkspace(windowList, activeWorkspaceId, focusedMonitorId, activeWindowAddress) {
        const ws = activeWorkspaceId;
        if (!(ws > 0))
            return [];
        let list = SwitcherCommon.windowsInWorkspace(windowList, ws, focusedMonitorId);

        // 1) sort "approx MRU" (stable enough for rotate step)
        list.sort((a, b) => {
            const fa = a?.focusHistoryID;
            const fb = b?.focusHistoryID;
            const da = (typeof fa === "number") ? fa : -1;
            const db = (typeof fb === "number") ? fb : -1;
            if (da !== db)
                return da - db;

            const aa = (a?.address ?? "");
            const ab = (b?.address ?? "");
            return aa < ab ? -1 : (aa > ab ? 1 : 0);
        });

        // 2) rotation: active window -> index 0
        const activeAddr = (activeWindowAddress && typeof activeWindowAddress === "string") ? activeWindowAddress : "";
        if (activeAddr.length) {
            const idx = list.findIndex(w => w?.address === activeAddr);
            if (idx > 0)
                list = list.slice(idx).concat(list.slice(0, idx));
        }

        return list;
    }

    function dispatchFocusWindowAddress(hyprland, address) {
        if (!address || typeof address !== "string")
            return;
        hyprland?.dispatch?.(`focuswindow address:${address}`);
    }

    function dispatchMoveWindowToWorkspace(hyprland, wsId, address, silent) {
        if (!(wsId > 0))
            return;
        if (!address || typeof address !== "string")
            return;
        const cmd = silent ? "movetoworkspacesilent" : "movetoworkspace";
        hyprland?.dispatch?.(`${cmd} ${wsId}, address:${address}`);
    }

    // Selection management utilities
    function clampSelection(selectedIndex, count) {
        if (count <= 0)
            return -1;
        if (selectedIndex < 0)
            return 0;
        if (selectedIndex >= count)
            return count - 1;
        return selectedIndex;
    }

    function selectNext(selectedIndex, count) {
        if (count <= 0)
            return -1;
        if (selectedIndex < 0)
            return 0;
        return (selectedIndex + 1) % count;
    }

    function selectPrev(selectedIndex, count) {
        if (count <= 0)
            return -1;
        if (selectedIndex < 0)
            return 0;
        return (selectedIndex - 1 + count) % count;
    }

    // Monitor dimension calculations
    function monitorWorkspaceWidth(monitorData, monitor) {
        if (!monitorData || !monitor)
            return 0;
        return (monitorData.transform % 2 === 1) ? ((monitor.height / monitor.scale) - (monitorData.reserved?.[0] ?? 0) - (monitorData.reserved?.[2] ?? 0)) : ((monitor.width / monitor.scale) - (monitorData.reserved?.[0] ?? 0) - (monitorData.reserved?.[2] ?? 0));
    }

    function monitorWorkspaceHeight(monitorData, monitor) {
        if (!monitorData || !monitor)
            return 0;
        return (monitorData.transform % 2 === 1) ? ((monitor.width / monitor.scale) - (monitorData.reserved?.[1] ?? 0) - (monitorData.reserved?.[3] ?? 0)) : ((monitor.height / monitor.scale) - (monitorData.reserved?.[1] ?? 0) - (monitorData.reserved?.[3] ?? 0));
    }

    // Multi-row layout calculation (centers items horizontally in each row)
    // Returns: { byKey: {}, totalH: number }
    // items: array of { key: string, w: number, h: number }
    function calculateMultiRowLayout(items, maxWidth, spacing) {
        const byKey = ({});
        let row = [];
        let rowW = 0;
        let rowMaxH = 0;
        let y = 0;

        function flushRow() {
            if (!row.length)
                return;
            const left = Math.max(0, (maxWidth - rowW) / 2);
            let x = left;
            for (let k = 0; k < row.length; k++) {
                const it = row[k];
                if (it.key)
                    byKey[it.key] = {
                        x,
                        y
                    };
                x += it.w;
                if (k !== row.length - 1)
                    x += spacing;
            }
            y += rowMaxH + spacing;
            row = [];
            rowW = 0;
            rowMaxH = 0;
        }

        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (row.length && (rowW + spacing + item.w) > maxWidth)
                flushRow();
            rowW += (row.length ? spacing : 0) + item.w;
            rowMaxH = Math.max(rowMaxH, item.h);
            row.push(item);
        }
        flushRow();

        const totalH = (items.length > 0) ? Math.max(0, y - spacing) : 0;
        return {
            byKey,
            totalH
        };
    }

    // Window coordinate transformation (monitor-local coordinates)
    function windowLocalX(windowData, monitorData) {
        return Math.max(((windowData?.at?.[0] ?? 0) - (monitorData?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)), 0);
    }

    function windowLocalY(windowData, monitorData) {
        return Math.max(((windowData?.at?.[1] ?? 0) - (monitorData?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)), 0);
    }
}
