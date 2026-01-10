import QtQuick
import Quickshell

import "../config"
import "../widgets"

Item {
    id: root

    required property int rowIndex
    required property var app

    property bool selected: false
    property bool hovered: false

    signal clicked(int rowIndex, var app)
    signal activated(int rowIndex, var app, var actionId)
    signal contextMenuRequested(int rowIndex, var app, real sceneX, real sceneY)

    width: parent ? parent.width : 0
    height: 54

    function _title() {
        const a = root.app;
        if (!a)
            return "";
        if (typeof a === "string")
            return a;
        const t = (a.name ?? a.display_name ?? a.displayName ?? a.app_id ?? a.appId ?? a.id ?? a.exec ?? a.command ?? "").toString();
        return t.length ? t : "(unknown app)";
    }

    function _comment() {
        const a = root.app;
        if (!a)
            return "";
        if (typeof a === "string")
            return "";
        return (a.comment ?? a.description ?? a.generic_name ?? a.genericName ?? a.exec ?? a.command ?? a.desktop_file ?? a.desktopFile ?? "").toString();
    }

    function _iconName() {
        const a = root.app;
        if (!a)
            return "";
        return (a.icon ?? a.icon_name ?? a.iconName ?? a.desktop_icon ?? a.desktopIcon ?? "").toString();
    }

    function _actions() {
        const a = root.app;
        if (!a || typeof a === "string")
            return [];
        const acts = a.actions ?? [];
        return Array.isArray(acts) ? acts : [];
    }

    function _desktopId() {
        const a = root.app;
        if (!a)
            return "";
        if (typeof a === "string")
            return a;
        return (a.desktop_id ?? a.desktopId ?? a.desktop_file ?? a.desktopFile ?? a.id ?? a.app_id ?? a.appId ?? "").toString();
    }

    function _exec() {
        const a = root.app;
        if (!a || typeof a === "string")
            return "";
        return (a.exec ?? a.command ?? "").toString();
    }

    function _menuModel() {
        const items = [];
        // Primary
        items.push({
            kind: "action",
            text: "Launch",
            actionId: undefined,
            enabled: true
        });

        // Desktop actions (from JSON)
        const acts = root._actions();
        for (let i = 0; i < acts.length; i++) {
            const a = acts[i] ?? {};
            items.push({
                kind: "action",
                text: (a.name ?? a.id ?? "Action").toString(),
                actionId: (a.id ?? "").toString(),
                enabled: true
            });
        }

        if (acts.length === 0) {
            items.push({
                kind: "info",
                text: "No actions",
                enabled: false
            });
        }

        // Useful info
        const did = root._desktopId();
        if (did.length)
            items.push({
                kind: "info",
                text: `ID: ${did}`,
                enabled: false
            });
        const ex = root._exec();
        if (ex.length)
            items.push({
                kind: "info",
                text: `Exec: ${ex}`,
                enabled: false
            });

        return items;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.selected ? Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.22) : (root.hovered ? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.08) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.00))
        border.width: 1
        border.color: root.selected ? Qt.rgba(Config.theme.barFill.r, Config.theme.barFill.g, Config.theme.barFill.b, 0.35) : Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.08)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: root.hovered = true
        onExited: root.hovered = false

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.clicked(root.rowIndex, root.app);
                const p = mouseArea.mapToItem(null, mouse.x, mouse.y);
                const px = (p && p.x !== undefined) ? p.x : 0;
                const py = (p && p.y !== undefined) ? p.y : 0;
                root.contextMenuRequested(root.rowIndex, root.app, isNaN(px) ? 0 : px, isNaN(py) ? 0 : py);
            }
        }

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked(root.rowIndex, root.app);
        }

        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activated(root.rowIndex, root.app, undefined);
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            width: 34
            height: 34
            radius: 12
            color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.12)

            SmartIcon {
                anchors.centerIn: parent
                pixelSize: 20
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.92)
                state: "default"
                icons: ({
                        default: root._iconName().length ? root._iconName() : "application-x-executable"
                    })
            }
        }

        Column {
            width: parent.width - 34 - 10
            spacing: 2

            Text {
                text: root._title()
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.92)
                font.pixelSize: 14
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root._comment()
                color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
                font.pixelSize: 11
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
