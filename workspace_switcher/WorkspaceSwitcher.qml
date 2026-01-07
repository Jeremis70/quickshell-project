import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../services"
import "../widgets"

Scope {
	id: workspaceSwitcher
	property bool open: false
	property int selectedIndex: -1
	property int hoveredWorkspaceId: -1
	property int pendingSwitchWorkspaceId: -1

	readonly property int activeWorkspaceId: HyprlandData.activeWorkspace?.id ?? -1
	readonly property var toplevels: ToplevelManager.toplevels

	readonly property var selectedWorkspace: (selectedIndex >= 0 && selectedIndex < activeWorkspaces.length)
		? activeWorkspaces[selectedIndex]
		: null

	readonly property var hoveredWorkspace: {
		const id = workspaceSwitcher.hoveredWorkspaceId
		if (!(id > 0)) return null
		const list = workspaceSwitcher.activeWorkspaces ?? []
		for (let i = 0; i < list.length; i++) {
			if ((list[i]?.id ?? -1) === id) return list[i]
		}
		return null
	}

	readonly property var activeWorkspaces: {
		return SwitcherCommon.calculateActiveWorkspaces(
			HyprlandData.workspaces,
			HyprlandData.windowList,
			workspaceSwitcher.activeWorkspaceId,
			Hyprland.focusedMonitor?.id
		)
	}

	function clampSelection() {
		const count = workspaceSwitcher.activeWorkspaces?.length ?? 0
		selectedIndex = SwitcherCommon.clampSelection(selectedIndex, count)
	}

	function selectNext() {
		const count = workspaceSwitcher.activeWorkspaces?.length ?? 0
		if (count <= 0) return
		selectedIndex = SwitcherCommon.selectNext(selectedIndex, count)
	}

	function selectPrev() {
		const count = workspaceSwitcher.activeWorkspaces?.length ?? 0
		if (count <= 0) return
		selectedIndex = SwitcherCommon.selectPrev(selectedIndex, count)
	}

	function commitSelectionAndClose() {
		const wsId = workspaceSwitcher.selectedWorkspace?.id ?? -1
		pendingSwitchWorkspaceId = (wsId > 0) ? wsId : -1
		workspaceSwitcher.open = false
		if (pendingSwitchWorkspaceId > 0) switchAfterClose.restart()
	}

	function switchWorkspaceAndClose(wsId) {
		pendingSwitchWorkspaceId = (wsId > 0) ? wsId : -1
		workspaceSwitcher.open = false
		if (pendingSwitchWorkspaceId > 0) switchAfterClose.restart()
	}

	Timer {
		id: switchAfterClose
		interval: 30
		repeat: false
		onTriggered: {
			const wsId = workspaceSwitcher.pendingSwitchWorkspaceId
			workspaceSwitcher.pendingSwitchWorkspaceId = -1
			if (!(wsId > 0)) return
			SwitcherCommon.dispatchSwitchWorkspace(Hyprland, workspaceSwitcher.activeWorkspaceId, wsId)
		}
	}

	onOpenChanged: {
		if (open) {
			hoveredWorkspaceId = -1
			selectedIndex = 0
			clampSelection()
		} else {
			hoveredWorkspaceId = -1
		}
	}

	onActiveWorkspacesChanged: clampSelection()

	Variants {
		id: variants
		model: Quickshell.screens

		PanelWindow {
			id: win
			required property var modelData
			screen: modelData

			readonly property HyprlandMonitor monitor: Hyprland.monitorFor(win.screen)
			readonly property bool monitorIsFocused: (Hyprland.focusedMonitor?.id === monitor?.id)

			visible: workspaceSwitcher.open && monitorIsFocused
			color: "transparent"
			exclusiveZone: 0

			WlrLayershell.namespace: "quickshell:workspace_switcher"
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

			readonly property var monitorData: HyprlandData.monitors.find(m => m.id === monitor?.id)
			readonly property real monitorWorkspaceWidth: SwitcherCommon.monitorWorkspaceWidth(monitorData, monitor)
			readonly property real monitorWorkspaceHeight: SwitcherCommon.monitorWorkspaceHeight(monitorData, monitor)

			readonly property real panelContentW: Math.min(sw * 0.80, 1100)
			readonly property real panelPadding: 14
			readonly property real tileSpacing: 12
            readonly property real tileMaxW: Math.min(sw * 0.22, 260)
            readonly property real tileMinW: 140

            // On choisit d'abord une largeur, puis on déduit la hauteur via le ratio du workspace
            readonly property real tileW: Math.max(tileMinW, tileMaxW)
            readonly property real tileH: Math.round(tileW / win.workspaceAspect)

			readonly property real tileInnerPad: 0
			readonly property real tilePreviewW: win.tileW
			readonly property real tilePreviewH: win.tileH

			readonly property real tileIdealInnerW: {
				const list = workspaceSwitcher.activeWorkspaces ?? []
				if (!list || list.length === 0) return win.tileW
				return list.length * win.tileW + Math.max(0, list.length - 1) * win.tileSpacing
			}

			readonly property real panelInnerW: Math.min(win.panelContentW, Math.max(titleText.implicitWidth, win.tileIdealInnerW))

			// Layout tiles into rows, centered horizontally (like AltTab).
			readonly property var tileLayout: {
				const list = workspaceSwitcher.activeWorkspaces ?? []
				const items = []
				for (let i = 0; i < list.length; i++) {
					const id = list[i]?.id ?? -1
					items.push({
						key: String(id),
						w: win.tileW,
						h: win.tileH
					})
				}
				const result = SwitcherCommon.calculateMultiRowLayout(items, win.panelInnerW, win.tileSpacing)
				const byId = ({})
				for (const key in result.byKey) {
					const numKey = parseInt(key)
					if (!isNaN(numKey)) byId[numKey] = result.byKey[key]
				}
				return { byId, totalH: result.totalH }
			}

            readonly property real workspaceAspect: {
                const mw = win.monitorWorkspaceWidth
                const mh = win.monitorWorkspaceHeight
                if (!(mw > 0) || !(mh > 0)) return 16/9
                return mw / mh
            }

			implicitWidth: win.panelInnerW + win.panelPadding * 2
			implicitHeight: win.panelPadding * 2 + titleText.implicitHeight + 10 + 1 + 10 + tilesArea.implicitHeight

			margins.left: Math.max(0, (sw - implicitWidth) / 2)
			margins.top: Math.max(0, (sh - implicitHeight) / 2)

			HyprlandFocusGrab {
				id: grab
				windows: [win]
				active: workspaceSwitcher.open && win.monitorIsFocused
				onCleared: () => {
					if (!active) workspaceSwitcher.open = false;
				}
			}

			Item {
				id: keyHandler
				anchors.fill: parent
				visible: workspaceSwitcher.open && win.monitorIsFocused
				focus: visible

				Keys.onPressed: event => {
					if (event.key === Qt.Key_Escape) {
						workspaceSwitcher.open = false
						event.accepted = true
					}
				}

				Keys.onReleased: event => {
					// Hyprland drives next/prev via IPC; we only need to close on Super release.
					if (workspaceSwitcher.open && !(event.modifiers & Qt.MetaModifier)) {
						workspaceSwitcher.commitSelectionAndClose()
						event.accepted = true
					}
				}
			}

			Rectangle {
				anchors.fill: parent
				radius: Config.theme.panelRadius
				color: Config.theme.panelBg

				border.width: 1
				border.color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.20)

				Column {
					anchors.fill: parent
					anchors.margins: win.panelPadding
					spacing: 10

					Text {
						id: titleText
						text: {
							const list = workspaceSwitcher.activeWorkspaces ?? []
							if (!list.length) return ""
							const ws = workspaceSwitcher.hoveredWorkspace ?? workspaceSwitcher.selectedWorkspace
							const id = ws?.id ?? -1
							if (!(id > 0)) return ""
							const count = SwitcherCommon.windowsInWorkspace(HyprlandData.windowList, id, Hyprland.focusedMonitor?.id)?.length ?? 0
							return `Workspace ${id}${count ? ` — ${count} window${count > 1 ? "s" : ""}` : ""}`
						}
						color: Config.theme.textColor
						font.family: (Config.typography.textFontFamily && Config.typography.textFontFamily.length)
							? Config.typography.textFontFamily
							: Qt.application.font.family
						font.pixelSize: 16
						elide: Text.ElideRight
						maximumLineCount: 1
					}

					Rectangle {
						width: Math.min(parent.width, 999999)
						height: 1
						color: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.10)
					}

					Item {
						id: tilesArea
						width: win.panelInnerW
						implicitHeight: win.tileLayout.totalH

						Repeater {
							model: workspaceSwitcher.activeWorkspaces
							delegate: Item {
								required property var modelData
								property var workspaceData: modelData
								readonly property int wsId: workspaceData?.id ?? -1
								readonly property bool selected: (workspaceSwitcher.selectedWorkspace?.id ?? -1) === wsId
								readonly property bool hovered: workspaceSwitcher.hoveredWorkspaceId === wsId

								// --- Lift/zoom tuning ---
								readonly property bool activeTile: (selected || hovered)
								readonly property real targetScale: selected ? 1.045 : (hovered ? 1.020 : 1.0)
								readonly property real targetZ:     selected ? 200   : (hovered ? 120   : 0)

								Behavior on z { NumberAnimation { duration: 90 } }

                                readonly property real workspacePreviewScale: {
                                    const mw = win.monitorWorkspaceWidth
                                    const mh = win.monitorWorkspaceHeight
                                    if (!(mw > 0) || !(mh > 0)) return 0.2
									// CONTAIN: le ratio du tile suit le workspace, donc ça remplit sans barres.
									return Math.min(win.tileW / mw, win.tileH / mh)
                                }

								x: (win.tileLayout.byId && wsId > 0 && win.tileLayout.byId[wsId]) ? win.tileLayout.byId[wsId].x : 0
								y: (win.tileLayout.byId && wsId > 0 && win.tileLayout.byId[wsId]) ? win.tileLayout.byId[wsId].y : 0
								width: win.tileW
								height: win.tileH
								z: targetZ

								// Wrapper animé: on lève + zoom le contenu sans bouger la "case" du layout
								Item {
									id: tileFx
									anchors.fill: parent
									transformOrigin: Item.Center

									scale: targetScale

									Behavior on scale {
										NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
									}

								// Offscreen workspace render at "preview size"
								Item {
									id: workspaceSource
									width: win.tileW
									height: win.tileH
									x: -100000
									y: -100000
									visible: workspaceSwitcher.open
									clip: true

									Repeater {
										model: SwitcherCommon.windowsInWorkspace(HyprlandData.windowList, wsId, Hyprland.focusedMonitor?.id)
										delegate: Item {
											required property var modelData
											property var windowData: modelData
											property var toplevel: SwitcherCommon.toplevelForAddress(workspaceSwitcher.toplevels, windowData?.address)

											readonly property real localX: SwitcherCommon.windowLocalX(windowData, win.monitorData)
											readonly property real localY: SwitcherCommon.windowLocalY(windowData, win.monitorData)

											x: Math.round(localX * workspacePreviewScale)
											y: Math.round(localY * workspacePreviewScale)
											width: Math.max(1, Math.round((windowData?.size?.[0] ?? 1) * workspacePreviewScale))
											height: Math.max(1, Math.round((windowData?.size?.[1] ?? 1) * workspacePreviewScale))
											clip: true

											ScreencopyView {
												anchors.fill: parent
												captureSource: (workspaceSwitcher.open && toplevel) ? toplevel : null
												live: workspaceSwitcher.open
											}
										}
									}
								}

								RoundedMaskedPreview {
									anchors.fill: parent
									sourceItem: workspaceSource
									radius: Math.max(0, Config.theme.panelRadius)
									live: workspaceSwitcher.open
								}

								Text {
									anchors.left: parent.left
									anchors.top: parent.top
									anchors.margins: 8
									text: `${wsId}`
									color: Config.theme.textColor
									font.pixelSize: 14
									z: 10
								}


								MouseArea {
									anchors.fill: parent
									hoverEnabled: true
									acceptedButtons: Qt.LeftButton
									cursorShape: Qt.PointingHandCursor
									onEntered: {
										if (wsId > 0) workspaceSwitcher.hoveredWorkspaceId = wsId
									}
									onExited: {
										if (workspaceSwitcher.hoveredWorkspaceId === wsId) workspaceSwitcher.hoveredWorkspaceId = -1
									}
									onClicked: {
										workspaceSwitcher.switchWorkspaceAndClose(wsId)
									}
								}

								Rectangle {
									anchors.fill: parent
									color: "transparent"
									radius: Math.max(0, Config.theme.panelRadius - 2)
									z: 50
									antialiasing: true
									border.width: (selected || hovered) ? 2 : 1
									border.color: selected
										? Config.theme.barFill
										: (hovered
											? Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.55)
											: Qt.rgba(Config.theme.textColor.r, Config.theme.textColor.g, Config.theme.textColor.b, 0.18))
								}

								} // Close tileFx wrapper
							}
						}
					}

				}
			}
		}
	}

	IpcHandler {
		target: "workspace_switcher"

		function toggle() {
			workspaceSwitcher.open = !workspaceSwitcher.open
		}

		function open() {
			HyprlandData.updateAll()
			workspaceSwitcher.open = true
		}

		function close() {
			workspaceSwitcher.commitSelectionAndClose()
		}

		function next() {
			if (!workspaceSwitcher.open) {
				HyprlandData.updateAll()
				workspaceSwitcher.open = true

				// Active workspace = index 0, so first Super+Tab should go to index 1
				workspaceSwitcher.selectedIndex = 0
				workspaceSwitcher.clampSelection()
			}
			workspaceSwitcher.selectNext()
		}

		function prev() {
			if (!workspaceSwitcher.open) {
				HyprlandData.updateAll()
				workspaceSwitcher.open = true
				workspaceSwitcher.selectedIndex = 0
				workspaceSwitcher.clampSelection()
			}
			workspaceSwitcher.selectPrev()
		}
	}
}
