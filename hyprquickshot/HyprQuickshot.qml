import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtCore

import "../services"

import "src"
import "../widgets" as AppWidgets

FreezeScreen {
    id: root
    visible: false

    signal finished
    signal canceled

    property var activeScreen: null
    property bool waitingForMonitor: false
    property bool running: false
    property bool saveToDisk: true
    property bool captureInProgress: false

    targetScreen: activeScreen

    property var hyprlandMonitor: Hyprland.focusedMonitor
    property string tempPath: ""
    property string pendingOutputPath: ""
    property bool pendingDeleteOutputAfterCopy: false
    // "menu" shows the chooser buttons without enabling a selector.
    property string mode: "menu"

    function cleanupTempFiles(extraOutputPath) {
        if (captureInProgress)
            captureProcess.running = false;
        if (tempPath && tempPath.length)
            Quickshell.execDetached(["rm", "-f", tempPath]);
        if (extraOutputPath && String(extraOutputPath).length)
            Quickshell.execDetached(["rm", "-f", String(extraOutputPath)]);
        tempPath = "";
    }

    function closeOverlay() {
        root.visible = false;
        root.waitingForMonitor = false;
        root.running = false;
        root.captureInProgress = false;
        if (captureProcess.running)
            captureProcess.running = false;
        root.activeScreen = null;
        root.hyprlandMonitor = Hyprland.focusedMonitor;
        root.mode = "menu";
    }

    function selectScreenAndCapture(monitor) {
        if (!monitor)
            return false;

        for (const screen of Quickshell.screens) {
            if (screen.name === monitor.name) {
                activeScreen = screen;
                hyprlandMonitor = monitor;

                const timestamp = Date.now();
                const path = Quickshell.cachePath(`hqs-base-${timestamp}.png`);
                tempPath = path;
                captureProcess.command = ["hqs", "capture", "-g", `${screen.x},${screen.y} ${screen.width}x${screen.height}`, path];
                if (captureProcess.running)
                    captureProcess.running = false;
                root.captureInProgress = true;
                captureProcess.running = true;
                return true;
            }
        }

        return false;
    }

    function start(newMode) {
        if (root.running)
            return;

        // Ensure we have up-to-date monitor/window geometry, especially when
        // quickshell was launched early via Hyprland exec-once.
        HyprlandData.updateAll();

        root.mode = (newMode && String(newMode).length) ? String(newMode) : "menu";
        root.running = true;
        root.visible = false;

        const monitor = Hyprland.focusedMonitor;
        if (monitor) {
            if (!selectScreenAndCapture(monitor))
                closeOverlay();
            return;
        }

        root.waitingForMonitor = true;
    }

    Connections {
        target: Hyprland
        enabled: root.waitingForMonitor

        function onFocusedMonitorChanged() {
            const monitor = Hyprland.focusedMonitor;
            if (!monitor)
                return;
            root.waitingForMonitor = false;
            if (!root.selectScreenAndCapture(monitor))
                root.closeOverlay();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.running
        onActivated: () => {
            root.cleanupTempFiles();
            root.closeOverlay();
            root.canceled();
        }
    }

    IpcHandler {
        target: "hyprquickshot"

        // Menu/normal mode: show buttons, let user choose region/window/screen.
        function open() {
            root.start("menu");
        }

        // Convenience entrypoints for specific modes.
        function region() {
            root.start("region");
        }

        function window() {
            root.start("window");
        }

        function screen() {
            root.start("screen");
        }

        function cancel() {
            if (!root.running)
                return;
            root.cleanupTempFiles();
            root.closeOverlay();
            root.canceled();
        }
    }

    Process {
        id: captureProcess
        running: false

        onExited: () => {
            root.captureInProgress = false;
            if (root.running)
                showTimer.start();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length)
                    console.log(s);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length)
                    console.log(s);
            }
        }
    }

    Timer {
        id: showTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (root.mode === "screen") {
                root.visible = false;
                root.processScreenshot(0, 0, root.targetScreen.width, root.targetScreen.height);
            } else {
                root.visible = true;
            }
        }
    }

    Process {
        id: screenshotProcess
        running: false

        onExited: () => {
            // screenshotProcess runs `hqs finalize`. After it exits, copy the
            // final image to clipboard (like the old wl-copy step) and do any
            // remaining cleanup.
            if (!root.pendingOutputPath || !root.pendingOutputPath.length) {
                root.closeOverlay();
                root.finished();
                return;
            }

            if (copyProcess.running)
                copyProcess.running = false;

            // Copy the file to clipboard without using a shell.
            // `hqs copy-file` streams the file into wl-copy's stdin.
            copyProcess.command = ["hqs", "copy-file", "--type", "image/png", root.pendingOutputPath];
            copyProcess.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
    }

    Process {
        id: copyProcess
        running: false

        onExited: () => {
            if (root.tempPath && root.tempPath.length)
                Quickshell.execDetached(["rm", "-f", root.tempPath]);
            root.tempPath = "";

            if (root.pendingDeleteOutputAfterCopy && root.pendingOutputPath && root.pendingOutputPath.length)
                Quickshell.execDetached(["rm", "-f", root.pendingOutputPath]);

            root.pendingOutputPath = "";
            root.pendingDeleteOutputAfterCopy = false;

            root.closeOverlay();
            root.finished();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length)
                    console.log(s);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const s = (this.text ?? "").toString().trim();
                if (s.length)
                    console.log(s);
            }
        }
    }

    function screenshotsDir() {
        return (Quickshell.env("HQS_SCREENSHOTS_DIR") || Quickshell.env("XDG_SCREENSHOTS_DIR") || (Quickshell.env("XDG_PICTURES_DIR") ? Quickshell.env("XDG_PICTURES_DIR") + "/Screenshots" : null) || (Quickshell.env("HOME") + "/Pictures/Screenshots"));
    }

    function processScreenshot(x, y, width, height) {
        const scale = hyprlandMonitor.scale;
        const scaledX = Math.round(x * scale);
        const scaledY = Math.round(y * scale);
        const scaledWidth = Math.round(width * scale);
        const scaledHeight = Math.round(height * scale);

        const picturesDir = screenshotsDir();
        const now = new Date();
        const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss");

        const outputPath = root.saveToDisk ? `${picturesDir}/screenshot-${timestamp}.png` : Quickshell.cachePath(`hqs-crop-${timestamp}.png`);

        root.pendingOutputPath = outputPath;
        root.pendingDeleteOutputAfterCopy = !root.saveToDisk;

        screenshotProcess.command = ["hqs", "finalize", "--base", `${tempPath}`, "--crop-px", `${scaledX}`, `${scaledY}`, `${scaledWidth}`, `${scaledHeight}`, "--delete-base", `${outputPath}`];

        screenshotProcess.running = true;
        root.visible = false;
    }

    RegionSelector {
        id: regionSelector
        visible: mode === "region"
        anchors.fill: parent

        dimOpacity: 0.6
        borderRadius: 10.0
        outlineThickness: 2.0

        onRegionSelected: (x, y, width, height) => {
            processScreenshot(x, y, width, height);
        }
    }

    WindowSelector {
        id: windowSelector
        visible: mode === "window"
        anchors.fill: parent

        monitor: root.hyprlandMonitor
        dimOpacity: 0.6
        borderRadius: 10.0
        outlineThickness: 2.0

        onRegionSelected: (x, y, width, height) => {
            processScreenshot(x, y, width, height);
        }
    }

    WrapperRectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40

        color: Qt.rgba(0.1, 0.1, 0.1, 0.8)
        radius: 12
        margin: 8

        Row {
            id: settingRow
            spacing: 25

            Row {
                id: buttonRow
                spacing: 8

                Repeater {
                    model: [
                        {
                            mode: "region",
                            icon: "screenshot-area"
                        },
                        {
                            mode: "window",
                            icon: "screenshot-window"
                        },
                        {
                            mode: "screen",
                            icon: "screenshot-screen"
                        }
                    ]

                    Button {
                        id: modeButton
                        implicitWidth: 48
                        implicitHeight: 48

                        background: Rectangle {
                            radius: 8
                            color: {
                                if (mode === modelData.mode)
                                    return Qt.rgba(0.3, 0.4, 0.7, 0.5);
                                if (modeButton.hovered)
                                    return Qt.rgba(0.4, 0.4, 0.4, 0.5);

                                return Qt.rgba(0.3, 0.3, 0.35, 0.5);
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                        }

                        contentItem: Item {
                            anchors.fill: parent

                            AppWidgets.SmartIcon {
                                anchors.centerIn: parent
                                pixelSize: 24
                                state: "default"
                                icons: ({
                                        default: modelData.icon
                                    })
                            }
                        }

                        onClicked: {
                            root.mode = modelData.mode;
                            if (modelData.mode === "screen")
                                processScreenshot(0, 0, root.targetScreen.width, root.targetScreen.height);
                        }
                    }
                }
            }

            Row {
                id: switchRow
                spacing: 8
                anchors.verticalCenter: buttonRow.verticalCenter

                Text {
                    text: "Save to disk"
                    color: "#ffffff"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                }

                Switch {
                    id: saveSwitch
                    checked: root.saveToDisk
                    onCheckedChanged: root.saveToDisk = checked
                }
            }
        }
    }
}
