import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../config"
import "../widgets" as W

Scope {
    id: micOsd

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSource ]
    }

    property bool audioReady: false

    Timer {
        interval: Config.motion.audioReadyDelayMs
        running: true
        repeat: false
        onTriggered: micOsd.audioReady = true
    }

    Connections {
        target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() { if (micOsd.audioReady) osdWin.show() }
        function onMutedChanged()  { if (micOsd.audioReady) osdWin.show() }
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.mic.autoHideDelayMs

        posX: Config.mic.posX
        posY: Config.mic.posY
        enterFrom: Config.mic.enterFrom
        offscreenPx: Config.mic.offscreenPx

        animMode: Config.mic.animMode
        slideDurationMs: Config.mic.slideDurationMs
        slideEasingOpen: Config.mic.slideEasingOpen
        slideEasingClose: Config.mic.slideEasingClose
        fadeDurationMs: Config.mic.fadeDurationMs
        fadeEasing: Config.mic.fadeEasing
        opacityShown: Config.mic.opacityShown
        opacityHidden: Config.mic.opacityHidden

        windowWidth: Config.mic.panelWidth
        windowHeight: Config.mic.panelHeight
        windowColor: Config.mic.windowColor

        readonly property string textFamily: (Config.typography.textFontFamily && Config.typography.textFontFamily.length)
            ? Config.typography.textFontFamily
            : Qt.application.font.family

        Rectangle {
            anchors.fill: parent
            radius: Config.theme.panelRadius
            color: Config.mic.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Config.layout.contentLeftMargin
                    rightMargin: Config.layout.contentRightMargin
                }

                W.SmartIcon {
                    Layout.alignment: Qt.AlignCenter
                    pixelSize: Config.mic.iconSize
                    color: Config.theme.textColor
                    fontFamily: Config.mic.iconFontFamily
                    icons: Config.mic.icons

                    state: {
                        var a = Pipewire.defaultAudioSource?.audio
                        if (!a) return "muted"
                        return a.muted ? "muted" : "unmuted"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var a = Pipewire.defaultAudioSource?.audio
                            if (a) {
                                a.muted = !a.muted
                            }
                        }
                    }
                }
            }
        }
    }
}
