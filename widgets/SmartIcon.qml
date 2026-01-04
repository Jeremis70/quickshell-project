import QtQuick
import Quickshell

Item {
	id: root

	// Etat logique (ex: "muted", "zero", "low", "medium", "high")
	property string state: ""

	// Map: { muted: "\uE74F", low: "...", ... }
	// Chaque valeur peut être:
	// - glyph (1 char, Private Use Area) -> rendu Text
	// - path (file:///... ou /... ou .png/.svg) -> rendu Image
	// - nom d'icône -> Quickshell.iconPath(name) -> rendu Image
	property var icons: ({ })

	// Taille / couleur
	property int pixelSize: 18
	property color color: "white"

	// Font utilisée SEULEMENT si la valeur est un glyph
	property string fontFamily: ""

	implicitWidth: pixelSize
	implicitHeight: pixelSize

	function _value() {
		if (!icons) return ""
		var v = icons[state]
		if (v === undefined || v === null) return ""
		return "" + v
	}

	function _isGlyph(v) {
		// 1 seul caractère dans la zone Private Use (ex: Segoe Fluent Icons)
		return v.length === 1 && v.charCodeAt(0) >= 0xE000
	}

	function _isPath(v) {
		// simple heuristique: suffisant en pratique
		return v.startsWith("file:") || v.startsWith("/") || v.endsWith(".png") || v.endsWith(".svg") || v.endsWith(".webp") || v.endsWith(".jpg") || v.endsWith(".jpeg")
	}

	function _resolvedSource(v) {
		if (_isGlyph(v)) return ""
		if (_isPath(v)) return v
		return Quickshell.iconPath(v)
	}

	// --- Mode font glyph (comportement actuel) ---
	Text {
		anchors.centerIn: parent
		visible: root._isGlyph(root._value())
		text: root._value()
		font.family: root.fontFamily
		font.pixelSize: root.pixelSize
		color: root.color
		renderType: Text.NativeRendering
	}

	// --- Mode image (nom d'icône ou path) ---
	Image {
		anchors.fill: parent
		visible: !root._isGlyph(root._value())
		source: root._resolvedSource(root._value())
		fillMode: Image.PreserveAspectFit
		smooth: true
		mipmap: true
	}
}
