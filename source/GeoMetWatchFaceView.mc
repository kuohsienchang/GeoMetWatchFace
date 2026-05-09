using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class GeoMetWatchFaceView extends WatchUi.WatchFace {

    hidden var _weatherStore;
    hidden var _geoMetClient;
    hidden var _chartRenderer;
    hidden var _fetchPending;
    hidden var _lastFetchEpoch;

    const REFRESH_ACTIVE_SEC = 3600;

    function initialize() {
        WatchFace.initialize();
        _weatherStore = new WeatherStore();
        _geoMetClient = new GeoMetClient();
        _chartRenderer = new ChartRenderer();
        _fetchPending = false;
        _lastFetchEpoch = 0;
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFaceLayout(dc));
    }

    function onShow() as Void {
        requestWeatherIfDue(true);
    }

    function onUpdate(dc as Dc) as Void {
        requestWeatherIfDue(false);

        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var snap = _weatherStore.getSnapshot();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (dc has :isLowPower && dc.isLowPower()) {
            drawAodView(dc, info, snap);
        } else {
            drawActiveView(dc, info, snap);
        }
    }

    function onPartialUpdate(dc as Dc) as Void {
        onUpdate(dc);
    }

    function requestWeatherIfDue(force as Boolean) as Void {
        if (_fetchPending) { return; }
        var nowEpoch = Time.now().value();
        var due = (nowEpoch - _lastFetchEpoch) >= REFRESH_ACTIVE_SEC;
        if (force || due) {
            _fetchPending = true;
            _geoMetClient.fetchSnapshotV2(method(:onWeatherResponse));
        }
    }

    function onWeatherResponse(payload as Dictionary) as Void {
        _fetchPending = false;
        _lastFetchEpoch = Time.now().value();
        _weatherStore.updateSnapshotV2(payload);
        WatchUi.requestUpdate();
    }

    function drawAodView(dc as Dc, info as Time.Gregorian.Info, snap as Dictionary) as Void {
        var c = snap[:current];
        var timeText = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tempText = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";

        dc.drawText(dc.getWidth()/2, dc.getHeight()/3, Graphics.FONT_XTINY, timeText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+28, Graphics.FONT_TINY, tempText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+48, Graphics.FONT_XTINY, _weatherStore.staleStateLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawActiveView(dc as Dc, info as Time.Gregorian.Info, snap as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var c = snap[:current];
        var timeText = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tempText = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";
        var feels = c[:feelsLikeC] == null ? "" : ("Feels " + c[:feelsLikeC].format("%.0f") + "°");

        dc.drawText(12, 8, Graphics.FONT_SMALL, timeText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w-12, 8, Graphics.FONT_SMALL, tempText, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(12, 32, Graphics.FONT_XTINY, feels, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w-12, 32, Graphics.FONT_XTINY, _weatherStore.staleStateLabel(), Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(12, 50, Graphics.FONT_TINY, c[:narrativeText], Graphics.TEXT_JUSTIFY_LEFT);

        _chartRenderer.drawHourlyChart(dc, 8, 76, w-16, (h*0.45).toNumber(), snap[:hourly]);
        _chartRenderer.drawDailyStrip(dc, 8, h-62, w-16, 54, snap[:daily]);
    }
}
