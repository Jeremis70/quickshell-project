import QtQuick
import Quickshell

Scope {
	id: osd

	Item {
		id: contentStash
		visible: false
	}

	default property alias content: contentStash.data

	// Public API
	property int windowWidth: 200
	property int windowHeight: 50
	property color windowColor: "transparent"

	// Placement
	property real posX: 0.5
	property real posY: 0.98
	property string enterFrom: "bottom" // left|right|top|bottom
	property int offscreenPx: 24

	// Auto-hide
	property int autoHideDelayMs: 2500
	// Auto-hide / hover behavior
	property bool hoverPausesAutoHide: true

	// Animation config
	property string animMode: "slide" // slide|fade|slide+fade

	property int slideDurationMs: 250
	property int slideEasingOpen: Easing.OutCubic
	property int slideEasingClose: Easing.InCubic

	property int fadeDurationMs: 200
	property int fadeEasing: Easing.InOutQuad

	property real opacityShown: 1.0
	property real opacityHidden: 0.0

	function show() {
		wantOpen = true
		keepAlive = true

		if (hoverPausesAutoHide && hovering) {
			hideTimer.stop()
		} else {
			hideTimer.restart()
		}
	}

	function hide() {
		wantOpen = false
	}

	// Internal state
	property bool wantOpen: false
	property bool keepAlive: false
	property bool hovering: false

	Timer {
		id: hideTimer
		interval: osd.autoHideDelayMs
		onTriggered: osd.hide()
	}

	LazyLoader {
		active: osd.keepAlive

		PanelWindow {
			id: win
			function attachContent() {
				// Move user content into the live window
				for (var i = contentStash.children.length - 1; i >= 0; --i) {
					contentStash.children[i].parent = contentHost
				}
			}

			function detachContent() {
				// Move user content back so it survives window destruction
				for (var i = contentHost.children.length - 1; i >= 0; --i) {
					contentHost.children[i].parent = contentStash
				}
			}

			function requestDestroyIfReady() {
				if (!win.canDestroyNow()) return
				win.detachContent()
				osd.keepAlive = false
			}

			exclusiveZone: 0

			implicitWidth: osd.windowWidth
			implicitHeight: osd.windowHeight
			color: osd.windowColor

			readonly property bool animSlide: osd.animMode === "slide" || osd.animMode === "slide+fade"
			readonly property bool animFade: osd.animMode === "fade" || osd.animMode === "slide+fade"

			function clamp01(v) { return Math.max(0, Math.min(1, v)); }

			readonly property var scr: win.screen
			readonly property real sw: scr ? scr.width : 0
			readonly property real sh: scr ? scr.height : 0

			readonly property real baseX: clamp01(osd.posX) * Math.max(0, sw - win.implicitWidth)
			readonly property real baseY: clamp01(osd.posY) * Math.max(0, sh - win.implicitHeight)

			function applyEnterAnchors() {
				win.anchors.left = false
				win.anchors.right = false
				win.anchors.top = false
				win.anchors.bottom = false

				if (osd.enterFrom === "right") win.anchors.right = true
				else win.anchors.left = true

				if (osd.enterFrom === "bottom") win.anchors.bottom = true
				else win.anchors.top = true
			}

			// 1 = hidden, 0 = visible
			property real slide: 1.0
			readonly property real slideT: animSlide ? slide : 0.0

			property real fade: osd.opacityHidden

			readonly property real visibleLeft: baseX
			readonly property real visibleTop: baseY
			readonly property real visibleRight: Math.max(0, sw - (baseX + win.implicitWidth))
			readonly property real visibleBottom: Math.max(0, sh - (baseY + win.implicitHeight))

			readonly property real hiddenH: -(win.implicitWidth + osd.offscreenPx)
			readonly property real hiddenV: -(win.implicitHeight + osd.offscreenPx)

			margins.left: (osd.enterFrom === "left")
				? (visibleLeft + (hiddenH - visibleLeft) * slideT)
				: (osd.enterFrom === "right" ? 0 : visibleLeft)

			margins.right: (osd.enterFrom === "right")
				? (visibleRight + (hiddenH - visibleRight) * slideT)
				: 0

			margins.top: (osd.enterFrom === "top")
				? (visibleTop + (hiddenV - visibleTop) * slideT)
				: (osd.enterFrom === "bottom" ? 0 : visibleTop)

			margins.bottom: (osd.enterFrom === "bottom")
				? (visibleBottom + (hiddenV - visibleBottom) * slideT)
				: 0

			Behavior on slide {
				NumberAnimation {
					id: slideAnim
					duration: osd.slideDurationMs
					easing.type: osd.wantOpen ? osd.slideEasingOpen : osd.slideEasingClose
				}
			}

			Behavior on fade {
				NumberAnimation {
					id: fadeAnim
					duration: osd.fadeDurationMs
					easing.type: osd.fadeEasing
				}
			}

			function canDestroyNow() {
				if (osd.wantOpen) return false

				var slideDone = !animSlide || (!slideAnim.running && win.slide >= 0.999)
				var fadeDone = !animFade || (!fadeAnim.running && win.fade <= (osd.opacityHidden + 0.001))

				return slideDone && fadeDone
			}

			Component.onCompleted: {
				applyEnterAnchors()
				attachContent()

				win.slide = 1.0
				win.fade = osd.opacityHidden

				if (osd.wantOpen) {
					if (animSlide) win.slide = 0.0
					if (animFade) win.fade = osd.opacityShown
				}
			}

			Connections {
				target: osd
				function onEnterFromChanged() { win.applyEnterAnchors() }
			}

			Connections {
				target: osd
				function onWantOpenChanged() {
					if (osd.wantOpen) {
						if (win.animSlide) win.slide = 0.0
						if (win.animFade) win.fade = osd.opacityShown
					} else {
						if (win.animSlide) win.slide = 1.0
						if (win.animFade) win.fade = osd.opacityHidden
					}
				}
			}

			Connections {
				target: slideAnim
				function onRunningChanged() {
					if (!slideAnim.running) win.requestDestroyIfReady()
				}
			}

			Connections {
				target: fadeAnim
				function onRunningChanged() {
					if (!fadeAnim.running) win.requestDestroyIfReady()
				}
			}

			Item {
				id: contentHost
				anchors.fill: parent
				opacity: win.animFade ? win.fade : osd.opacityShown
			}

			MouseArea {
				// Top-level hover lock (should not block clicks)
				anchors.fill: parent
				hoverEnabled: true
				acceptedButtons: Qt.NoButton
				onEntered: {
					osd.hovering = true
					if (osd.hoverPausesAutoHide) hideTimer.stop()
				}
				onExited: {
					osd.hovering = false
					if (osd.hoverPausesAutoHide && osd.wantOpen) hideTimer.restart()
				}
			}
		}
	}
}
