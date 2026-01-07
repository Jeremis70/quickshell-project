import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../widgets" as W

Scope {
    id: keyboardBacklightOsd

    W.OsdWatcher {
        id: watcher
        osdWindow: osdWin

        sampleFn: function () {
            var maxRaw = watcher.readIntFromFileView(maxBrightnessFile);
            var curRaw = watcher.readIntFromFileView(curBrightnessFile);
            if (maxRaw === undefined || curRaw === undefined || maxRaw <= 0)
                return undefined;

            return {
                cur: curRaw,
                max: maxRaw
            };
        }
    }

    property bool userAdjusting: false
    property int pendingLevel: -1

    Process {
        id: setProc
    }

    function setKeyboardBacklight(level) {
        var max = watcher.current ? watcher.current.max : 0;
        if (max <= 0)
            return;
        level = Math.max(0, Math.min(level, max));

        keyboardBacklightOsd.userAdjusting = true;
        keyboardBacklightOsd.pendingLevel = level;

        adjustTimeout.restart();

        watcher.ingest({
            cur: level,
            max: max
        });

        setProc.command = ["sh", "-lc", "printf %d " + level + " > " + Config.keyboardBacklight.brightnessPath];
        setProc.running = true;
    }

    function ingestFromFiles() {
        var state = watcher.sampleFn ? watcher.sampleFn() : undefined;
        if (state === undefined)
            return;

        // While adjusting, ignore sysfs echo unless it matches the pending level.
        if (keyboardBacklightOsd.userAdjusting) {
            if (state.cur !== keyboardBacklightOsd.pendingLevel)
                return;
            keyboardBacklightOsd.userAdjusting = false;
            keyboardBacklightOsd.pendingLevel = -1;
            watcher.ingest(state, {
                suppressShow: true
            });
            return;
        }

        watcher.ingest(state);
    }

    // Polling is the reliable way for sysfs LEDs
    Timer {
        id: adjustTimeout
        interval: 300
        repeat: false
        onTriggered: {
            keyboardBacklightOsd.userAdjusting = false;
            keyboardBacklightOsd.pendingLevel = -1;
            // force resync
            watcher.requestReload(curBrightnessFile);
            watcher.requestReload(maxBrightnessFile);
        }
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            // force refresh to avoid stale reads
            watcher.requestReload(curBrightnessFile);
            watcher.requestReload(maxBrightnessFile);
        }
    }

    FileView {
        id: maxBrightnessFile
        path: Config.keyboardBacklight.maxBrightnessPath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: keyboardBacklightOsd.ingestFromFiles()
    }

    FileView {
        id: curBrightnessFile
        path: Config.keyboardBacklight.brightnessPath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: keyboardBacklightOsd.ingestFromFiles()
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.keyboardBacklight.autoHideDelayMs
        hoverPausesAutoHide: Config.keyboardBacklight.hoverPausesAutoHide

        posX: Config.keyboardBacklight.posX
        posY: Config.keyboardBacklight.posY
        enterFrom: Config.keyboardBacklight.enterFrom
        offscreenPx: Config.keyboardBacklight.offscreenPx

        animMode: Config.keyboardBacklight.animMode
        slideDurationMs: Config.keyboardBacklight.slideDurationMs
        slideEasingOpen: Config.keyboardBacklight.slideEasingOpen
        slideEasingClose: Config.keyboardBacklight.slideEasingClose
        fadeDurationMs: Config.keyboardBacklight.fadeDurationMs
        fadeEasing: Config.keyboardBacklight.fadeEasing
        opacityShown: Config.keyboardBacklight.opacityShown
        opacityHidden: Config.keyboardBacklight.opacityHidden

        windowWidth: Config.keyboardBacklight.panelWidth
        windowHeight: Config.keyboardBacklight.panelHeight
        windowColor: Config.keyboardBacklight.windowColor

        Rectangle {
            anchors.fill: parent
            radius: Config.theme.panelRadius
            color: Config.keyboardBacklight.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Config.layout.contentLeftMargin
                    rightMargin: Config.layout.contentRightMargin
                }

                W.SmartIcon {
                    Layout.alignment: Qt.AlignCenter
                    pixelSize: Config.keyboardBacklight.iconSize
                    color: Config.theme.textColor
                    fontFamily: Config.keyboardBacklight.iconFontFamily
                    icons: Config.keyboardBacklight.icons

                    state: {
                        var cur = watcher.current ? watcher.current.cur : 0;
                        var max = watcher.current ? watcher.current.max : 0;

                        if (cur <= 0)
                            return "off";
                        if (cur < max)
                            return "low";
                        return "high";
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cur = watcher.current ? watcher.current.cur : 0;
                            var max = watcher.current ? watcher.current.max : 0;

                            if (max <= 0)
                                return;
                            var next = cur + 1;
                            if (next > max)
                                next = 0;

                            keyboardBacklightOsd.setKeyboardBacklight(next);
                        }
                    }
                }
            }
        }
    }
}
