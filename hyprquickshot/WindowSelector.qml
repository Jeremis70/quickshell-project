import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    property var monitor: Hyprland.focusedMonitor
    property var workspace: monitor?.activeWorkspace
    property var windows: workspace?.toplevels ?? []

    signal checkHover(real mouseX, real mouseY)
    signal regionSelected(real x, real y, real width, real height)

    // Shader customization properties
    property real dimOpacity: 0.6
    property real borderRadius: 10.0
    property real outlineThickness: 2.0
    property url fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")

    property point startPos
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    function resetSelection() {
        root.startPos = Qt.point(0, 0);
        root.selectionX = 0;
        root.selectionY = 0;
        root.selectionWidth = 0;
        root.selectionHeight = 0;
    }

    onVisibleChanged: {
        if (!visible)
            resetSelection();
    }

    Behavior on selectionX {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionY {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionHeight {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionWidth {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }

    // Shader overlay
    ShaderEffect {
        anchors.fill: parent
        z: 0

        property vector4d selectionRect: Qt.vector4d(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
        property real dimOpacity: root.dimOpacity
        property vector2d screenSize: Qt.vector2d(root.width, root.height)
        property real borderRadius: root.borderRadius
        property real outlineThickness: root.outlineThickness

        fragmentShader: root.fragmentShader
    }

    Repeater {
        model: root.windows

        Item {
            required property var modelData

            Connections {
                target: root

                function onCheckHover(mouseX, mouseY) {
                    const monitorX = root.monitor?.x ?? root.monitor?.lastIpcObject?.x ?? 0;
                    const monitorY = root.monitor?.y ?? root.monitor?.lastIpcObject?.y ?? 0;

                    const at = modelData?.at ?? modelData?.lastIpcObject?.at;
                    const size = modelData?.size ?? modelData?.lastIpcObject?.size;
                    if (!at || !size)
                        return;

                    const windowX = (at[0] ?? 0) - monitorX;
                    const windowY = (at[1] ?? 0) - monitorY;

                    const width = (size[0] ?? 0);
                    const height = (size[1] ?? 0);
                    if (!(width > 0) || !(height > 0))
                        return;

                    if (mouseX >= windowX && mouseX <= windowX + width && mouseY >= windowY && mouseY <= windowY + height) {
                        root.selectionX = windowX;
                        root.selectionY = windowY;
                        root.selectionWidth = width;
                        root.selectionHeight = height;
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 3
        hoverEnabled: true

        onPositionChanged: mouse => {
            root.checkHover(mouse.x, mouse.y);
        }

        onReleased: mouse => {
            if (mouse.x >= root.selectionX && mouse.x <= root.selectionX + root.selectionWidth && mouse.y >= root.selectionY && mouse.y <= root.selectionY + root.selectionHeight) {
                root.regionSelected(Math.round(root.selectionX), Math.round(root.selectionY), Math.round(root.selectionWidth), Math.round(root.selectionHeight));
            }
        }
    }
}
