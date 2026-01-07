import QtQuick
import QtQuick.Effects
import "../config"

// Reusable component for rendering a source with rounded corners using MultiEffect masking
Item {
	id: root
	
	// The source item to render (e.g., ShaderEffectSource)
	property var sourceItem: null
	
	// Optional source rectangle (for cropping)
	property rect sourceRect: Qt.rect(0, 0, 0, 0)
	
	// Corner radius for the mask
	property real radius: Math.max(0, Config.theme.panelRadius)
	
	// Whether to show the preview
	property bool live: true
	
	ShaderEffectSource {
		id: effectSource
		anchors.fill: parent
		sourceItem: root.sourceItem
		sourceRect: (root.sourceRect.width > 0 && root.sourceRect.height > 0) ? root.sourceRect : Qt.rect(0, 0, 0, 0)
		recursive: true
		live: root.live
		hideSource: true
		smooth: true
		visible: false
	}
	
	Rectangle {
		id: maskRect
		anchors.fill: parent
		radius: root.radius
		color: "white"
		antialiasing: true
		layer.enabled: true
		layer.samples: 4
		visible: false
	}
	
	MultiEffect {
		anchors.fill: parent
		source: effectSource
		maskEnabled: true
		maskSource: maskRect
		maskSpreadAtMin: 0.20
		maskThresholdMin: 0.2
		maskThresholdMax: 1.0
		visible: root.live
		z: 1
	}
}
