import QtQuick

QtObject {
    id: watcher

    // The OsdWindow instance to show on real state changes.
    property var osdWindow: null

    // Function returning the current state (any JS value). Return `undefined` to mean "not ready".
    property var sampleFn: null

    // Optional normalization before storage/comparison (e.g. quantization).
    property var normalizeFn: null

    // Optional custom equality comparison.
    property var equalsFn: null

    // Internal lifecycle
    property bool initialized: false
    property var current: undefined

    function reset() {
        initialized = false;
        current = undefined;
    }

    function quantizeReal(v, step) {
        if (!(step > 0))
            return v;
        return Math.round(v / step) * step;
    }

    function _normalize(state) {
        return normalizeFn ? normalizeFn(state) : state;
    }

    function _stableStringify(v) {
        try {
            return JSON.stringify(v);
        } catch (e) {
            return String(v);
        }
    }

    function _equals(a, b) {
        if (equalsFn)
            return equalsFn(a, b);

        var ta = typeof a;
        var tb = typeof b;
        if (ta !== tb)
            return false;

        if (a === null || b === null)
            return a === b;
        if (ta === "object")
            return _stableStringify(a) === _stableStringify(b);

        // number/string/bool/undefined/function
        return a === b;
    }

    // opts: { suppressShow: bool }
    function ingest(state, opts) {
        if (state === undefined)
            return false;

        var next = _normalize(state);

        if (!initialized) {
            current = next;
            initialized = true;
            return false;
        }

        var changed = !_equals(next, current);
        current = next;

        if (changed && !(opts && opts.suppressShow) && osdWindow) {
            osdWindow.show();
        }

        return changed;
    }

    function ingestSample(opts) {
        if (!sampleFn)
            return false;
        return ingest(sampleFn(), opts);
    }

    function ingestOptimistic(state) {
        // Update internal state immediately without showing the OSD.
        // Useful for user interactions; the real backend change signal should trigger showing.
        return ingest(state, {
            suppressShow: true
        });
    }

    // FileView helpers: keep reload -> onLoaded -> ingest flow explicit.
    function requestReload(fileView) {
        if (!fileView)
            return;
        fileView.reload();
    }

    function readIntFromFileView(fileView) {
        var s = (fileView ? fileView.text() : "");
        s = s.trim();
        if (!s.length)
            return undefined;
        var n = parseInt(s, 10);
        return isNaN(n) ? undefined : n;
    }
}
