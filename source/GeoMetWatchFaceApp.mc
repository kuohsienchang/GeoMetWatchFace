using Toybox.Application;
using Toybox.WatchUi;

class GeoMetWatchFaceApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new GeoMetWatchFaceView();
        return [ view, new GeoMetWatchFaceDelegate(view) ];
    }
}
