using Toybox.Application;
using Toybox.WatchUi;
class GeoMetWatchFaceApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [ new GeoMetWatchFaceView(), new GeoMetWatchFaceDelegate() ]; }
}
