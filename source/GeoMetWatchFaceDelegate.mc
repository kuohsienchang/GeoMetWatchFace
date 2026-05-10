using Toybox.WatchUi;
using Toybox.Time;

class GeoMetWatchFaceDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _lastTapEpoch;

    function initialize(view as GeoMetWatchFaceView) {
        BehaviorDelegate.initialize();
        _view = view;
        _lastTapEpoch = 0;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        var now = Time.now().value();
        var delta = now - _lastTapEpoch;
        _lastTapEpoch = now;

        // double tap emulation window
        if (delta > 0 && delta <= 1) {
            _view.togglePage();
            return true;
        }

        // single-tap fallback (works better across devices)
        _view.togglePage();
        return true;
    }
}
