import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../widgets" as W

Scope {
    id: brightnessOsd

    W.OsdWatcher {
        id: watcher
        osdWindow: osdWin

        sampleFn: function() {
            var cur = watcher.readIntFromFileView(curBrightnessFile)
            var max = watcher.readIntFromFileView(maxBrightnessFile)
            if (cur === undefined || max === undefined || max <= 0) return undefined

            return brightnessOsd._percentFromRaw(cur, max)
        }
    }

    // When user changes brightness via slider, ignore sysfs echo for a short time
    property bool userAdjusting: false

    function _readIntFromFileView(fv) {
        var s = (fv ? fv.text() : "").trim()
        var n = parseInt(s, 10)
        return isNaN(n) ? -1 : n
    }

    function clampInt(v, lo, hi) {
        if (v < lo) return lo
        if (v > hi) return hi
        return v
    }

    function clampReal(v, lo, hi) {
        if (v < lo) return lo
        if (v > hi) return hi
        return v
    }

    function _percentFromRaw(cur, max) {
        // pct = (cur/max)^(1/K) * 100
        var ratio = cur / max
        ratio = clampReal(ratio, 0.0, 1.0)

        var k = Config.brightness.exponentK
        if (!(k > 0)) k = 1.0

        var pct = Math.round(Math.pow(ratio, 1.0 / k) * 100.0)
        return clampInt(pct, 0, 100)
    }

    // Map slider UI (0..1) -> real brightnessctl percent (min..100)
    function uiToRealPercent(ui01) {
        ui01 = clampReal(ui01, 0.0, 1.0)

        var minP = clampInt(Config.brightness.minPercent, 0, 100)
        if (minP >= 100) return 100

        var realPct = minP + ui01 * (100 - minP)
        return clampInt(Math.round(realPct), minP, 100)
    }

    // Map real brightnessctl percent (min..100) -> slider UI (0..1)
    function realToUi(realPct) {
        var minP = clampInt(Config.brightness.minPercent, 0, 100)
        realPct = clampInt(Math.round(realPct), 0, 100)

        if (minP >= 100) return 1.0
        if (realPct <= minP) return 0.0

        var ui01 = (realPct - minP) / (100.0 - minP)
        return clampReal(ui01, 0.0, 1.0)
    }

    function ingestFromFiles() {
        watcher.ingestSample({ suppressShow: brightnessOsd.userAdjusting })
    }

    function brightnessBucketKey(pct) {
        if (pct < 0) pct = 0
        var ts = Config.brightness.bucketThresholds
        if (!ts || ts.length < 1) ts = [15, 30, 45, 60, 75, 90]

        for (var i = 0; i < ts.length; i++) {
            if (pct <= ts[i]) return "brightness_" + (i + 1)
        }
        return "brightness_" + (ts.length + 1)
    }

    Process { id: brightnessSetProc }

    Timer {
        id: userAdjustCooldown
        interval: 250
        repeat: false
        onTriggered: brightnessOsd.userAdjusting = false
    }

    function setBrightnessPercent(realPct) {
        var minP = clampInt(Config.brightness.minPercent, 0, 100)
        realPct = clampInt(Math.round(realPct), minP, 100)

        userAdjusting = true
        userAdjustCooldown.restart()

        watcher.ingest(realPct)

        brightnessSetProc.command = [
            "brightnessctl",
            "-e" + Math.round(Config.brightness.exponentK),
            "-n2",
            "set",
            realPct + "%"
        ]
        brightnessSetProc.running = true
    }

    FileView {
        id: maxBrightnessFile
        path: Config.brightness.maxBrightnessPath
        preload: true
        blockLoading: false
        watchChanges: false
        onLoaded: brightnessOsd.ingestFromFiles()
    }

    FileView {
        id: curBrightnessFile
        path: Config.brightness.brightnessPath
        preload: true
        blockLoading: false
        watchChanges: true

        onLoaded: brightnessOsd.ingestFromFiles()

        onFileChanged: {
            watcher.requestReload(this)
        }
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.brightness.autoHideDelayMs
        hoverPausesAutoHide: Config.brightness.hoverPausesAutoHide

        posX: Config.brightness.posX
        posY: Config.brightness.posY
        enterFrom: Config.brightness.enterFrom
        offscreenPx: Config.brightness.offscreenPx

        animMode: Config.brightness.animMode
        slideDurationMs: Config.brightness.slideDurationMs
        slideEasingOpen: Config.brightness.slideEasingOpen
        slideEasingClose: Config.brightness.slideEasingClose
        fadeDurationMs: Config.brightness.fadeDurationMs
        fadeEasing: Config.brightness.fadeEasing
        opacityShown: Config.brightness.opacityShown
        opacityHidden: Config.brightness.opacityHidden

        windowWidth: Config.brightness.panelWidth
        windowHeight: Config.brightness.panelHeight
        windowColor: Config.brightness.windowColor

        readonly property string textFamily: (Config.typography.textFontFamily && Config.typography.textFontFamily.length)
            ? Config.typography.textFontFamily
            : Qt.application.font.family

        Rectangle {
            anchors.fill: parent
            radius: Config.theme.panelRadius
            color: Config.brightness.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Config.layout.contentLeftMargin
                    rightMargin: Config.layout.contentRightMargin
                }

                W.SmartIcon {
                    pixelSize: Config.brightness.iconSize
                    color: Config.theme.textColor
                    icons: Config.brightness.icons

                    state: {
                        var pct = (watcher.current === undefined) ? -1 : watcher.current
                        return brightnessOsd.brightnessBucketKey(pct)
                    }
                }

                W.OsdSlider {
                    Layout.fillWidth: true

                    barHeight: Config.brightness.barHeight
                    radius: Config.brightness.barRadius
                    backgroundColor: Config.brightness.barBg
                    fillColor: Config.brightness.barFill

                    extraHitX: Config.brightness.barHitExtraX
                    extraHitY: Config.brightness.barHitExtraY

                    animDurationMs: Config.motion.fillAnimDurationMs
                    animEasing: Config.motion.fillEasing

                    value: (watcher.current === undefined)
                        ? 0
                        : brightnessOsd.realToUi(watcher.current)

                    onUserChanged: function(newValue) {
                        var realPct = brightnessOsd.uiToRealPercent(newValue)
                        brightnessOsd.setBrightnessPercent(realPct)
                    }
                }

                TextMetrics {
                    id: brightnessMetrics
                    text: "100"
                    font.pixelSize: Config.brightness.textFontSize
                    font.family: osdWin.textFamily
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Config.brightness.textLeftMargin
                    Layout.preferredWidth: brightnessMetrics.width
                    Layout.minimumWidth: brightnessMetrics.width

                    text: (watcher.current === undefined) ? 0 : watcher.current
                    font.pixelSize: Config.brightness.textFontSize
                    font.family: osdWin.textFamily
                    color: Config.theme.textColor
                }
            }
        }
    }
}
