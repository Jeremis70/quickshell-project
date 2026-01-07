import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../widgets" as W

Scope {
    id: powerSourceOsd

    W.OsdWatcher {
        id: watcher
        osdWindow: osdWin

        sampleFn: function () {
            var raw = watcher.readIntFromFileView(onlineFile);
            if (raw === undefined)
                return -1;
            return raw > 0 ? 1 : 0;
        }
    }

    Timer {
        interval: Config.powerSource.pollIntervalMs
        running: true
        repeat: true
        onTriggered: {
            watcher.requestReload(onlineFile);
        }
    }

    FileView {
        id: onlineFile
        path: Config.powerSource.onlinePath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: watcher.ingestSample()
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.powerSource.autoHideDelayMs
        hoverPausesAutoHide: Config.powerSource.hoverPausesAutoHide

        posX: Config.powerSource.posX
        posY: Config.powerSource.posY
        enterFrom: Config.powerSource.enterFrom
        offscreenPx: Config.powerSource.offscreenPx

        animMode: Config.powerSource.animMode
        slideDurationMs: Config.powerSource.slideDurationMs
        slideEasingOpen: Config.powerSource.slideEasingOpen
        slideEasingClose: Config.powerSource.slideEasingClose
        fadeDurationMs: Config.powerSource.fadeDurationMs
        fadeEasing: Config.powerSource.fadeEasing
        opacityShown: Config.powerSource.opacityShown
        opacityHidden: Config.powerSource.opacityHidden

        windowWidth: Config.powerSource.panelWidth
        windowHeight: Config.powerSource.panelHeight
        windowColor: Config.powerSource.windowColor

        Rectangle {
            anchors.fill: parent
            radius: Config.theme.panelRadius
            color: Config.powerSource.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Config.layout.contentLeftMargin
                    rightMargin: Config.layout.contentRightMargin
                }

                W.SmartIcon {
                    Layout.alignment: Qt.AlignCenter
                    pixelSize: Config.powerSource.iconSize
                    color: Config.theme.textColor
                    icons: Config.powerSource.icons

                    state: (watcher.current === -1) ? "unknown" : ((watcher.current > 0) ? "ac" : "no_ac")
                }
            }
        }
    }
}
