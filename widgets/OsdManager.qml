pragma Singleton

import QtQuick

QtObject {
	id: mgr

	property var _windows: []

	function registerWindow(win) {
		if (!win) return
		if (_windows.indexOf(win) !== -1) return
		_windows.push(win)
	}

	function unregisterWindow(win) {
		var idx = _windows.indexOf(win)
		if (idx === -1) return
		_windows.splice(idx, 1)
	}

	function requestShow(win) {
		// Hide any other open OSDs before showing this one.
		for (var i = 0; i < _windows.length; i++) {
			var other = _windows[i]
			if (!other || other === win) continue
			if (other.wantOpen) other.hide()
		}
	}
}
