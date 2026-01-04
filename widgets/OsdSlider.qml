import QtQuick

Item {
	id: slider

	property real value: 0.0 // 0..1
	property color backgroundColor: "#00000000"
	property color fillColor: "#ffffffff"
	property int barHeight: 6
	property real radius: 999
	property int extraHitX: 0
	property int extraHitY: 0
	property int animDurationMs: 150
	property int animEasing: Easing.OutCubic

	signal userChanged(real newValue)

	property real _dragValue: 0.0
	readonly property real _effectiveValue: mouseArea.pressed ? _dragValue : value

	implicitHeight: barHeight

	function clamp01(v) { return Math.max(0.0, Math.min(1.0, v)); }

	Rectangle {
		id: bar
		anchors.fill: parent
		radius: slider.radius
		color: slider.backgroundColor

		Rectangle {
			id: fill
			anchors {
				left: parent.left
				top: parent.top
				bottom: parent.bottom
			}
			width: parent.width * slider.clamp01(slider._effectiveValue)
			radius: parent.radius
			color: slider.fillColor

			Behavior on width {
				NumberAnimation {
					duration: slider.animDurationMs
					easing.type: slider.animEasing
				}
			}
		}

		MouseArea {
			id: mouseArea
			anchors {
				fill: parent
				leftMargin: -slider.extraHitX
				rightMargin: -slider.extraHitX
				topMargin: -slider.extraHitY
				bottomMargin: -slider.extraHitY
			}

			hoverEnabled: true

			function setFromMouse(mouseX) {
				if (bar.width <= 0) return

				var p = bar.mapFromItem(this, mouseX, 0)
				var xOnBar = p.x

				var nv = xOnBar / bar.width
				nv = slider.clamp01(nv)

				slider._dragValue = nv
				slider.userChanged(nv)
			}

			onPressed: setFromMouse(mouseX)
			onPositionChanged: {
				if (!pressed) return
				setFromMouse(mouseX)
			}
			onPressedChanged: {
				if (pressed) slider._dragValue = slider.clamp01(slider.value)
			}
		}
	}
}
