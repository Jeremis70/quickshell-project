import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Disable with: QS_DESKTOP_INDEXER_AUTOSTART=0
    property bool enabled: {
        const v = (Quickshell.env("QS_DESKTOP_INDEXER_AUTOSTART") ?? "1").toString().toLowerCase();
        return !(v === "0" || v === "false" || v === "no");
    }

    function _log(kind, text) {
        const s = (text ?? "").toString().trim();
        if (!s.length)
            return;
        console.log(`[desktop-indexer][daemon][${kind}] ${s}`);
    }

    Component.onCompleted: {
        if (!enabled)
            return;
        startDaemon.running = true;
    }

    Process {
        id: startDaemon

        // Use a login shell so PATH includes user env (e.g. ~/.cargo/bin).
        command: ["desktop-indexer", "start-daemon"]

        stdout: StdioCollector {
            onStreamFinished: root._log("stdout", this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._log("stderr", this.text)
        }
    }
}
