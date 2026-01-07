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
        objects: [Pipewire.defaultAudioSource]
    }

    property bool audioReady: false
    property var audioObj: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    function volume01() {
        var s = watcher.current;
        return s ? ((s.volumeQ ?? 0) / 1000.0) : 0;
    }

    Timer {
        interval: Config.motion.audioReadyDelayMs
        running: true
        repeat: false
        onTriggered: micOsd.audioReady = true
    }

    W.OsdWatcher {
        id: watcher
        osdWindow: osdWin

        normalizeFn: function (state) {
            if (!state)
                return state;
            return {
                volumeQ: Math.round((state.volume ?? 0) * 1000),
                muted: !!state.muted
            };
        }

        sampleFn: function () {
            var a = micOsd.audioObj;
            if (!a)
                return undefined;
            return {
                volume: a.volume ?? 0,
                muted: !!a.muted
            };
        }
    }

    onAudioReadyChanged: {
        if (!audioReady)
            return;
        watcher.reset();
        watcher.ingestSample();
    }

    onAudioObjChanged: {
        if (!micOsd.audioReady)
            return;
        watcher.reset();
        watcher.ingestSample();
    }

    Connections {
        target: micOsd.audioObj
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            if (micOsd.audioReady)
                watcher.ingestSample();
        }
        function onMutedChanged() {
            if (micOsd.audioReady)
                watcher.ingestSample();
        }
    }

    W.OsdWindow {
        id: osdWin

        autoHideDelayMs: Config.mic.autoHideDelayMs
        hoverPausesAutoHide: Config.mic.hoverPausesAutoHide

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

        readonly property string textFamily: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family

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
                        var s = watcher.current;
                        if (!s)
                            return "muted";
                        return s.muted ? "muted" : "unmuted";
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var a = micOsd.audioObj;
                            if (!a)
                                return;
                            var nextMuted = !a.muted;
                            a.muted = nextMuted;

                            if (!micOsd.audioReady)
                                return;
                            watcher.ingestOptimistic({
                                volume: micOsd.volume01(),
                                muted: nextMuted
                            });
                        }
                    }
                }
            }
        }
    }
}
