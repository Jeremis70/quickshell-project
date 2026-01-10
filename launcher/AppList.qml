import QtQuick

import "../config"

Item {
    id: root

    // List of apps (JSON array)
    property var apps: []

    // State passed from parent
    property bool searching: false
    property string query: ""
    property string searchError: ""

    // Selection is controlled by the parent
    property int selectedIndex: -1
    signal requestSelect(int index, var app)
    signal requestActivate(int index, var app, var actionId)
    signal requestContextMenu(int index, var app, real sceneX, real sceneY)

    implicitWidth: 200
    implicitHeight: 200

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 10
        model: root.apps
        spacing: 6
        clip: true

        delegate: AppListItem {
            required property int index
            required property var modelData

            width: list.width
            rowIndex: index
            app: modelData
            selected: root.selectedIndex === rowIndex

            onClicked: (i, a) => root.requestSelect(i, a)
            onActivated: (i, a, actionId) => root.requestActivate(i, a, actionId)
            onContextMenuRequested: (i, a, sx, sy) => root.requestContextMenu(i, a, sx, sy)
        }

        footer: Item {
            width: list.width
            height: 10
        }
    }

    Text {
        anchors.centerIn: parent
        visible: (root.apps?.length ?? 0) === 0 && ((root.searching) || (root.searchError?.length ?? 0) === 0)
        text: root.searching ? "Searching…" : (root.query.length ? "No results" : "Start typing to search")
        color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.45)
        font.pixelSize: 14
    }
}
