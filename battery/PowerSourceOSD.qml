import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../widgets" as W

Scope {
    id: powerSourceOsd

    // -1 = unknown/uninitialized, 0 = battery, 1 = AC
    property int lastOnline: -1
    property bool initialized: false

    function _readIntFromFileView(fv) {
        var s = (fv ? fv.text() : "").trim()
        var n = parseInt(s, 10)
        return isNaN(n) ? -1 : n
    }

    function updateOnlineAndMaybeShow() {
        var onlineRaw = _readIntFromFileView(onlineFile)
        if (onlineRaw < 0) {
            if (!powerSourceOsd.initialized) {
                powerSourceOsd.lastOnline = -1
                powerSourceOsd.initialized = true
                return
            }

            if (powerSourceOsd.lastOnline !== -1) {
                powerSourceOsd.lastOnline = -1
                osdWin.show()
            }
            return
        }

        var online = onlineRaw > 0 ? 1 : 0

        if (!powerSourceOsd.initialized) {
            powerSourceOsd.lastOnline = online
            powerSourceOsd.initialized = true
            return
        }

        if (powerSourceOsd.lastOnline !== online) {
            powerSourceOsd.lastOnline = online
            osdWin.show()
        }
    }

    Timer {
        interval: Config.powerSource.pollIntervalMs
        running: true
        repeat: true
        onTriggered: {
            onlineFile.reload()
        }
    }

    FileView {
        id: onlineFile
        path: Config.powerSource.onlinePath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: powerSourceOsd.updateOnlineAndMaybeShow()
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

                    state: (powerSourceOsd.lastOnline === -1)
                        ? "unknown"
                        : ((powerSourceOsd.lastOnline > 0) ? "ac" : "no_ac")
                }
            }
        }
    }
}
