using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class GeoMetWatchFaceView extends WatchUi.WatchFace {

    const PAGE_WEATHER = 0;
    const PAGE_ASTRO = 1;
    const REFRESH_SEC = 3600;

    hidden var _page;
    hidden var _weatherStore;
    hidden var _geoMetClient;
    hidden var _healthStore;
    hidden var _astroStore;
    hidden var _chart;

    hidden var _fetchPending;
    hidden var _lastFetchEpoch;

    function initialize() {
        WatchFace.initialize();

        _page = PAGE_WEATHER;

        _weatherStore = new WeatherStore();
        _geoMetClient = new GeoMetClient();
        _healthStore = new HealthStore();
        _astroStore = new AstroStore();
        _chart = new ChartRenderer();

        _fetchPending = false;
        _lastFetchEpoch = 0;
    }

    function togglePage() as Void {
        _page = (_page == PAGE_WEATHER) ? PAGE_ASTRO : PAGE_WEATHER;
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFaceLayout(dc));
    }

    function onShow() as Void {
        requestData(true);
    }

    function onUpdate(dc as Dc) as Void {
        requestData(false);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (dc has :isLowPower && dc.isLowPower()) {
            drawAod(dc);
            return;
        }

        if (_page == PAGE_WEATHER) {
            drawWeatherPage(dc);
        } else {
            drawAstroPage(dc);
        }
    }

    function onPartialUpdate(dc as Dc) as Void {
        onUpdate(dc);
    }

    function requestData(force as Boolean) as Void {
        if (_fetchPending) { return; }

        var now = Time.now().value();
        if (force || ((now - _lastFetchEpoch) >= REFRESH_SEC)) {
            _fetchPending = true;
            _geoMetClient.fetchSnapshotV4(method(:onWeatherData));
            _astroStore.fetchAstro(method(:onAstroData));
        }
    }

    function onWeatherData(payload as Dictionary) as Void {
        _weatherStore.updateSnapshotV4(payload);
        _lastFetchEpoch = Time.now().value();
        _fetchPending = false;
        WatchUi.requestUpdate();
    }

    function onAstroData(payload as Dictionary) as Void {
        _astroStore.updateFromPayload(payload);
        WatchUi.requestUpdate();
    }

    function drawAod(dc as Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var s = _weatherStore.getSnapshot();
        var c = s[:current];

        var timeText = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tempText = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";

        dc.drawText(dc.getWidth()/2, dc.getHeight()/3, Graphics.FONT_XTINY, timeText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+28, Graphics.FONT_TINY, tempText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+48, Graphics.FONT_XTINY, _weatherStore.freshnessLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawWeatherPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var s = _weatherStore.getSnapshot();
        var c = s[:current];

        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var tm = Lang.format("$1$:$2$", [now.hour.format("%02d"), now.min.format("%02d")]);
        var tp = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";
        var feels = c[:feelsLikeC] == null ? "" : ("Feels " + c[:feelsLikeC].format("%.0f") + "°");

        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(14, 8, Graphics.FONT_SMALL, tm, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w-14, 8, Graphics.FONT_SMALL, tp, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(14, 30, Graphics.FONT_XTINY, feels, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(14, 46, Graphics.FONT_TINY, c[:narrativeText], Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w-14, 30, Graphics.FONT_XTINY, _weatherStore.freshnessLabel(), Graphics.TEXT_JUSTIFY_RIGHT);

        // side health bars
        drawSideBar(dc, 8, 56, 8, h-130, _healthStore.getHeartRate(), 200, 0xF800, "HR");
        drawSideBar(dc, w-16, 56, 8, h-130, _healthStore.getSpO2(), 100, 0x07FF, "O2");

        // chart + strip
        _chart.drawHourlyChart(dc, 24, 56, w-48, (h*0.50).toNumber(), s[:hourly]);
        _chart.drawDailyStrip(dc, 24, h-72, w-48, 60, s[:daily]);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h-4, Graphics.FONT_XTINY, "Tap -> Astro", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawAstroPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var a = _astroStore.getSnapshot();

        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 8, Graphics.FONT_SMALL, "STARGAZING", Graphics.TEXT_JUSTIFY_CENTER);

        drawKV(dc, 18, 38,  "Moon", a[:moonPhase] + " " + a[:moonIllumPct].format("%.0f") + "%");
        drawKV(dc, 18, 58,  "Sunset", a[:sunset]);
        drawKV(dc, 18, 78,  "Sunrise", a[:sunrise]);
        drawKV(dc, 18, 98,  "Astro End", a[:astroTwilightEnd]);
        drawKV(dc, 18, 118, "Astro Start", a[:astroTwilightStart]);
        drawKV(dc, 18, 138, "Cloud", a[:cloudPct].format("%.0f") + "%");
        drawKV(dc, 18, 158, "Seeing", a[:seeingScore].format("%.0f"));
        drawKV(dc, 18, 178, "Transp.", a[:transparencyScore].format("%.0f"));

        drawScore(dc, w/2, h-72, a[:stargazingScore]);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h-6, Graphics.FONT_XTINY, "Tap -> Weather • " + a[:updatedText], Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawKV(dc as Dc, x as Number, y as Number, k as String, v as String) as Void {
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, k + ":", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x+92, y, Graphics.FONT_XTINY, v, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawSideBar(dc as Dc, x as Number, y as Number, bw as Number, bh as Number, val as Number or Null, maxv as Number, col as Number, lbl as String) as Void {
        dc.setColor(0x39E7, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, bh);

        if (val != null) {
            var r = val / maxv;
            if (r < 0) { r = 0; }
            if (r > 1) { r = 1; }
            var fh = (bh*r).toNumber();
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x+1, y + bh - fh, bw-2, fh);
        }

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + (bw/2), y-10, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawScore(dc as Dc, cx as Number, cy as Number, score as Number) as Void {
        dc.setColor(0x39E7, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 42);

        dc.setColor(0x07E0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy-6, Graphics.FONT_SMALL, score.format("%.0f"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy+14, Graphics.FONT_XTINY, "SKY SCORE", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
