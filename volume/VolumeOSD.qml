import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../config"
import "../widgets" as W

Scope {
    id: volumeOsd

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    property bool audioReady: false

    Timer {
        interval: Config.motion.audioReadyDelayMs
        running: true
        repeat: false
        onTriggered: volumeOsd.audioReady = true
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() { if (volumeOsd.audioReady) osdWin.show() }
        function onMutedChanged()  { if (volumeOsd.audioReady) osdWin.show() }
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.volume.autoHideDelayMs
        hoverPausesAutoHide: Config.volume.hoverPausesAutoHide

        posX: Config.volume.posX
        posY: Config.volume.posY
        enterFrom: Config.volume.enterFrom
        offscreenPx: Config.volume.offscreenPx

        animMode: Config.volume.animMode
        slideDurationMs: Config.volume.slideDurationMs
        slideEasingOpen: Config.volume.slideEasingOpen
        slideEasingClose: Config.volume.slideEasingClose
        fadeDurationMs: Config.volume.fadeDurationMs
        fadeEasing: Config.volume.fadeEasing
        opacityShown: Config.volume.opacityShown
        opacityHidden: Config.volume.opacityHidden

        windowWidth: Config.volume.panelWidth
        windowHeight: Config.volume.panelHeight
        windowColor: Config.volume.windowColor

        readonly property string textFamily: (Config.typography.textFontFamily && Config.typography.textFontFamily.length)
            ? Config.typography.textFontFamily
            : Qt.application.font.family

        Rectangle {
            anchors.fill: parent
            radius: Config.theme.panelRadius
            color: Config.volume.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Config.layout.contentLeftMargin
                    rightMargin: Config.layout.contentRightMargin
                }

                W.SmartIcon {
                    Layout.alignment: Qt.AlignVCenter

                    pixelSize: Config.volume.iconSize
                    color: Config.theme.textColor
                    fontFamily: Config.volume.iconFontFamily
                    icons: Config.volume.icons

                    state: {
                        var a = Pipewire.defaultAudioSink?.audio
                        var v = a?.volume ?? 0

                        if (a?.muted) return "muted"
                        if (v === 0) return "zero"
                        if (v <= Config.volume.iconLowThreshold) return "low"
                        if (v <= Config.volume.iconMediumThreshold) return "medium"
                        return "high"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var a = Pipewire.defaultAudioSink?.audio
                            if (!a) return
                            a.muted = !a.muted
                            osdWin.show()
                        }
                    }
                }

                W.OsdSlider {
                    Layout.fillWidth: true

                    barHeight: Config.volume.barHeight
                    radius: Config.volume.barRadius
                    backgroundColor: Config.volume.barBg
                    fillColor: Config.volume.barFill

                    extraHitX: Config.volume.barHitExtraX
                    extraHitY: Config.volume.barHitExtraY

                    animDurationMs: Config.motion.fillAnimDurationMs
                    animEasing: Config.motion.fillEasing

                    value: Pipewire.defaultAudioSink?.audio.volume ?? 0
                    onUserChanged: function(newValue) {
                        var a = Pipewire.defaultAudioSink?.audio
                        if (!a) return
                        a.muted = false
                        a.volume = newValue
                        osdWin.show()
                    }
                }

                TextMetrics {
                    id: volumeMetrics
                    text: "100"
                    font.pixelSize: Config.volume.textFontSize
                    font.family: osdWin.textFamily
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Config.volume.textLeftMargin
                    Layout.preferredWidth: volumeMetrics.width
                    Layout.minimumWidth: volumeMetrics.width

                    text: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)
                    font.pixelSize: Config.volume.textFontSize
                    font.family: osdWin.textFamily
                    color: Config.theme.textColor
                }
            }
        }
    }
}
