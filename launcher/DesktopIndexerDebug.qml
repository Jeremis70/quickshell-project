import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Enable with: QS_DESKTOP_INDEXER_DEBUG=1 quickshell ...
    property bool enabled: {
        const v = (Quickshell.env("QS_DESKTOP_INDEXER_DEBUG") || "").toLowerCase();
        return v === "1" || v === "true" || v === "yes";
    }

    function _log(section, text) {
        const s = (text ?? "").toString().trim();
        if (s.length)
            console.log(`[desktop-indexer][${section}] ${s}`);
        else
            console.log(`[desktop-indexer][${section}] (no output)`);
    }

    function runDebug() {
        // 1) Inspect env inside QuickShell (PATH + resolution)
        envCheck.running = true;

        // 2) Try direct exec (will fail if PATH doesn't include ~/.cargo/bin)
        directHelp.running = true;
        directStatus.running = true;
        directSearch.running = true;
    }

    Component.onCompleted: {
        if (!enabled)
            return;

        _log("info", `starting debug; PATH=${Quickshell.env("PATH") || ""}`);
        runDebug();
    }

    Process {
        id: envCheck
        command: ["sh", "-lc", ["set -e", "echo 'QS_USER='${USER:-?}", "echo 'QS_HOME='${HOME:-?}", "echo 'QS_XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR:-?}", "echo 'QS_PATH='${PATH:-?}", "echo 'which desktop-indexer:'", "command -v desktop-indexer || true", "echo 'desktop-indexer --help (first line):'", "desktop-indexer --help 2>/dev/null | head -n 1 || true",].join("; "),]

        stdout: StdioCollector {
            onStreamFinished: root._log("env stdout", this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._log("env stderr", this.text)
        }
    }

    Process {
        id: directHelp
        command: ["desktop-indexer", "--help"]

        stdout: StdioCollector {
            onStreamFinished: root._log("direct --help stdout", this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._log("direct --help stderr", this.text)
        }
    }

    Process {
        id: directStatus
        command: ["desktop-indexer", "status", "--json", "--trace"]

        stdout: StdioCollector {
            onStreamFinished: root._log("direct status stdout", this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._log("direct status stderr", this.text)
        }
    }

    Process {
        id: directSearch
        command: ["desktop-indexer", "search", "code", "--limit", "10", "--json", "--trace"]

        stdout: StdioCollector {
            onStreamFinished: root._log("direct search stdout", this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: root._log("direct search stderr", this.text)
        }
    }
}
