using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class GeoMetWatchFaceView extends WatchUi.WatchFace {

    hidden var _weatherStore;
    hidden var _geoMetClient;
    hidden var _chart;
    hidden var _fetchPending;
    hidden var _lastFetchEpoch;

    const REFRESH_SEC = 3600;

    function initialize() {
        WatchFace.initialize();
        _weatherStore = new WeatherStore();
        _geoMetClient = new GeoMetClient();
        _chart = new ChartRenderer();
        _fetchPending = false;
        _lastFetchEpoch = 0;
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFaceLayout(dc));
    }

    function onShow() as Void {
        requestWeather(true);
    }

    function onUpdate(dc as Dc) as Void {
        requestWeather(false);
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var s = _weatherStore.getSnapshot();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (dc has :isLowPower && dc.isLowPower()) {
            drawAOD(dc, info, s);
        } else {
            drawActive(dc, info, s);
        }
    }

    function requestWeather(force as Boolean) as Void {
        if (_fetchPending) { return; }
        var now = Time.now().value();
        if (force || ((now - _lastFetchEpoch) >= REFRESH_SEC)) {
            _fetchPending = true;
            _geoMetClient.fetchSnapshotV2(method(:onWeather));
        }
    }

    function onWeather(p as Dictionary) as Void {
        _fetchPending = false;
        _lastFetchEpoch = Time.now().value();
        _weatherStore.updateSnapshotV2(p);
        WatchUi.requestUpdate();
    }

    function drawAOD(dc as Dc, info as Time.Gregorian.Info, s as Dictionary) as Void {
        var c = s[:current];
        var tm = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tt = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";

        dc.drawText(dc.getWidth()/2, dc.getHeight()/3, Graphics.FONT_XTINY, tm, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+28, Graphics.FONT_TINY, tt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+48, Graphics.FONT_XTINY, _weatherStore.staleStateLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawActive(dc as Dc, info as Time.Gregorian.Info, s as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var c = s[:current];

        // Header like reference style
        var tm = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var temp = c[:tempC] == null ? "--°" : c[:tempC].format("%.0f") + "°";
        var feels = c[:feelsLikeC] == null ? "" : ("Feels " + c[:feelsLikeC].format("%.0f") + "°");

        dc.drawText(12, 6, Graphics.FONT_SMALL, tm, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w - 12, 6, Graphics.FONT_SMALL, temp, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(12, 28, Graphics.FONT_XTINY, feels, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(12, 44, Graphics.FONT_TINY, c[:narrativeText], Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w - 12, 28, Graphics.FONT_XTINY, _weatherStore.staleStateLabel(), Graphics.TEXT_JUSTIFY_RIGHT);

        // Main trend chart in middle
        var cx = 8;
        var cy = 66;
        var cw = w - 16;
        var ch = (h * 0.52).toNumber();
        _chart.drawHourlyChart(dc, cx, cy, cw, ch, s[:hourly]);

        // Bottom simplified forecast
        var sy = h - 64;
        _chart.drawDailyStrip(dc, 8, sy, w - 16, 56, s[:daily]);
    }

    function onPartialUpdate(dc as Dc) as Void {
        onUpdate(dc);
    }
}
