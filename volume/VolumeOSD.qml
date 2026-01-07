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
        objects: [Pipewire.defaultAudioSink]
    }

    property bool audioReady: false
    property var audioObj: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    function volume01() {
        var s = watcher.current;
        return s ? ((s.volumeQ ?? 0) / 1000.0) : 0;
    }

    Timer {
        interval: Config.motion.audioReadyDelayMs
        running: true
        repeat: false
        onTriggered: volumeOsd.audioReady = true
    }

    W.OsdWatcher {
        id: watcher
        osdWindow: osdWin

        // PipeWire can produce small float noise; quantize before comparing.
        normalizeFn: function (state) {
            if (!state)
                return state;
            return {
                volumeQ: Math.round((state.volume ?? 0) * 1000),
                muted: !!state.muted
            };
        }

        sampleFn: function () {
            var a = volumeOsd.audioObj;
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
        if (!volumeOsd.audioReady)
            return;
        watcher.reset();
        watcher.ingestSample();
    }

    Connections {
        target: volumeOsd.audioObj
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            if (volumeOsd.audioReady)
                watcher.ingestSample();
        }
        function onMutedChanged() {
            if (volumeOsd.audioReady)
                watcher.ingestSample();
        }
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

        readonly property string textFamily: (Config.typography.textFontFamily && Config.typography.textFontFamily.length) ? Config.typography.textFontFamily : Qt.application.font.family

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
                        var s = watcher.current;
                        var v = volumeOsd.volume01();

                        if (s && s.muted)
                            return "muted";
                        if (v === 0)
                            return "zero";
                        if (v <= Config.volume.iconLowThreshold)
                            return "low";
                        if (v <= Config.volume.iconMediumThreshold)
                            return "medium";
                        return "high";
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var a = volumeOsd.audioObj;
                            if (!a)
                                return;
                            var nextMuted = !a.muted;
                            a.muted = nextMuted;

                            if (!volumeOsd.audioReady)
                                return;
                            watcher.ingestOptimistic({
                                volume: volumeOsd.volume01(),
                                muted: nextMuted
                            });
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

                    value: volumeOsd.volume01()
                    onUserChanged: function (newValue) {
                        var a = volumeOsd.audioObj;
                        if (!a)
                            return;
                        var shouldUnmute = newValue > a.volume;
                        if (shouldUnmute)
                            a.muted = false;
                        a.volume = newValue;

                        if (!volumeOsd.audioReady)
                            return;
                        watcher.ingestOptimistic({
                            volume: newValue,
                            muted: shouldUnmute ? false : a.muted
                        });
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

                    text: Math.round(volumeOsd.volume01() * 100)
                    font.pixelSize: Config.volume.textFontSize
                    font.family: osdWin.textFamily
                    color: Config.theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
