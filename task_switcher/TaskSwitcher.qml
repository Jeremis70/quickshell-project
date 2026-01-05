import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

Scope {
	id: taskSwitcher
	property bool open: false
	property int selectedIndex: -1
	readonly property var toplevels: ToplevelManager.toplevels.values
	readonly property int toplevelCount: toplevels?.length ?? 0
	readonly property var selectedToplevel: (selectedIndex >= 0 && selectedIndex < toplevelCount)
		? toplevels[selectedIndex]
		: null

	function clampSelection() {
		if (toplevelCount <= 0) {
			selectedIndex = -1
			return
		}
		if (selectedIndex < 0) selectedIndex = 0
		if (selectedIndex >= toplevelCount) selectedIndex = toplevelCount - 1
	}

	function selectNext() {
		if (toplevelCount <= 0) return
		if (selectedIndex < 0) selectedIndex = 0
		else selectedIndex = (selectedIndex + 1) % toplevelCount
	}

	function selectPrev() {
		if (toplevelCount <= 0) return
		if (selectedIndex < 0) selectedIndex = 0
		else selectedIndex = (selectedIndex - 1 + toplevelCount) % toplevelCount
	}

	onOpenChanged: {
		if (open) {
			selectedIndex = 0
			clampSelection()
		}
	}

	onToplevelCountChanged: clampSelection()

	Variants {
		id: variants
		model: Quickshell.screens

		PanelWindow {
			id: win
			required property var modelData
			screen: modelData

			readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
			readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

			visible: taskSwitcher.open && monitorIsFocused
			color: "transparent"
			exclusiveZone: 0

			WlrLayershell.namespace: "quickshell:task_switcher"
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

			anchors {
				left: true
				top: true
				right: false
				bottom: false
			}

			readonly property var scr: win.screen
			readonly property real sw: scr ? scr.width : 0
			readonly property real sh: scr ? scr.height : 0

			implicitWidth: 320
			implicitHeight: 120

			margins.left: Math.max(0, (sw - implicitWidth) / 2)
			margins.top: Math.max(0, (sh - implicitHeight) / 2)

			HyprlandFocusGrab {
				id: grab
				windows: [win]
				active: taskSwitcher.open && win.monitorIsFocused
				onCleared: () => {
					if (!active) taskSwitcher.open = false;
				}
			}

			Item {
				id: keyHandler
				anchors.fill: parent
				visible: taskSwitcher.open && win.monitorIsFocused
				focus: visible

				Keys.onPressed: event => {
					if (event.key === Qt.Key_Escape) {
						taskSwitcher.open = false
						event.accepted = true
					}
				}

				Keys.onReleased: event => {
					// Hyprland drives next/prev via IPC; we only need to close on Alt release.
					if (taskSwitcher.open && !(event.modifiers & Qt.AltModifier)) {
						taskSwitcher.open = false
						event.accepted = true
					}
				}
			}

			Rectangle {
				anchors.fill: parent
				radius: Config.theme.panelRadius
				color: Config.theme.panelBg

				border.width: 1
				border.color: "#30FFFFFF"

				Text {
					anchors.centerIn: parent
					text: {
						if (taskSwitcher.toplevelCount <= 0) return "Alt-Tab (0)"
						const idx = Math.max(0, taskSwitcher.selectedIndex)
						const addr = taskSwitcher.selectedToplevel?.HyprlandToplevel?.address
						return `Alt-Tab ${idx + 1}/${taskSwitcher.toplevelCount} ${addr !== undefined ? `(0x${addr})` : ""}`
					}
					color: Config.theme.textColor
					font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length)
						? Config.typography.textFontFamily
						: Qt.application.font.family
					font.pixelSize: 18
				}
			}
		}
	}

	IpcHandler {
		target: "task_switcher"

		function toggle() {
			taskSwitcher.open = !taskSwitcher.open
		}

		function open() {
			taskSwitcher.open = true
		}

		function close() {
			taskSwitcher.open = false
		}

		function next() {
			if (!taskSwitcher.open) taskSwitcher.open = true
			taskSwitcher.selectNext()
		}

		function prev() {
			if (!taskSwitcher.open) taskSwitcher.open = true
			taskSwitcher.selectPrev()
		}
	}
}
