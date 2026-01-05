import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../widgets" as W

Scope {
    id: keyboardBacklightOsd

    property int lastBrightness: -1
    property int maxBrightness: 0

    property bool userAdjusting: false
    property int pendingLevel: -1

    Process {
        id: setProc
    }

function setKeyboardBacklight(level) {
    var max = keyboardBacklightOsd.maxBrightness
    if (max <= 0) return

    level = Math.max(0, Math.min(level, max))

    keyboardBacklightOsd.userAdjusting = true
    keyboardBacklightOsd.pendingLevel = level

    adjustTimeout.restart()

    keyboardBacklightOsd.lastBrightness = level
    osdWin.show()

    setProc.command = [
        "sh", "-lc",
        "printf %d " + level + " > " + Config.keyboardBacklight.brightnessPath
    ]
    setProc.running = true
}


    function _readIntFromFileView(fv) {
        var s = (fv ? fv.text() : "").trim()
        var n = parseInt(s, 10)
        return isNaN(n) ? -1 : n
    }

function updateBrightnessAndMaybeShow() {
    var maxRaw = _readIntFromFileView(maxBrightnessFile)
    var curRaw = _readIntFromFileView(curBrightnessFile)

    if (maxRaw <= 0 || curRaw < 0) return

    keyboardBacklightOsd.maxBrightness = maxRaw

    if (keyboardBacklightOsd.userAdjusting) {
        if (curRaw === keyboardBacklightOsd.pendingLevel) {
            keyboardBacklightOsd.userAdjusting = false
            keyboardBacklightOsd.pendingLevel = -1
            keyboardBacklightOsd.lastBrightness = curRaw
        }
        return
    }

    if (keyboardBacklightOsd.lastBrightness === -1) {
        keyboardBacklightOsd.lastBrightness = curRaw
        return
    }

    if (keyboardBacklightOsd.lastBrightness !== curRaw) {
        keyboardBacklightOsd.lastBrightness = curRaw
        osdWin.show()
    }
}


    // Polling is the reliable way for sysfs LEDs
    Timer {
        id: adjustTimeout
        interval: 300
        repeat: false
        onTriggered: {
            keyboardBacklightOsd.userAdjusting = false
            keyboardBacklightOsd.pendingLevel = -1
            // force resync
            curBrightnessFile.reload()
            maxBrightnessFile.reload()
            keyboardBacklightOsd.updateBrightnessAndMaybeShow()
        }
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            // force refresh to avoid stale reads
            curBrightnessFile.reload()
            maxBrightnessFile.reload()
            keyboardBacklightOsd.updateBrightnessAndMaybeShow()
        }
    }

    FileView {
        id: maxBrightnessFile
        path: Config.keyboardBacklight.maxBrightnessPath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: keyboardBacklightOsd.updateBrightnessAndMaybeShow()
    }

    FileView {
        id: curBrightnessFile
        path: Config.keyboardBacklight.brightnessPath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: keyboardBacklightOsd.updateBrightnessAndMaybeShow()
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
                        var cur = keyboardBacklightOsd.lastBrightness
                        var max = keyboardBacklightOsd.maxBrightness

                        if (cur <= 0) return "off"
                        if (cur < max) return "low"
                        return "high"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cur = keyboardBacklightOsd.lastBrightness
                            var max = keyboardBacklightOsd.maxBrightness

                            if (max <= 0) return

                            var next = cur + 1
                            if (next > max)
                                next = 0

                            keyboardBacklightOsd.setKeyboardBacklight(next)
                        }               
                    }
                }

            }
        }
    }
}
