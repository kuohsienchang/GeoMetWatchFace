using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.WatchUi;

class GeoMetWatchFaceView extends WatchUi.WatchFace {

    const PAGE_WEATHER = 0;
    const PAGE_ASTRO   = 1;
    const REFRESH_SEC  = 3600;

    hidden var _page;
    hidden var _weatherStore;
    hidden var _geoMetClient;
    hidden var _astroStore;
    hidden var _healthStore;
    hidden var _chartRenderer;

    hidden var _fetchPending;
    hidden var _lastFetchEpoch;

    function initialize() {
        WatchFace.initialize();
        _page = PAGE_WEATHER;

        _weatherStore  = new WeatherStore();
        _geoMetClient  = new GeoMetClient();
        _astroStore    = new AstroStore();
        _healthStore   = new HealthStore();
        _chartRenderer = new ChartRenderer();

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

    // ---------- AOD ----------

    function drawAod(dc as Dc) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var s = _weatherStore.getSnapshot();
        var c = s[:current];

        var tm = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tp = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";

        dc.drawText(dc.getWidth()/2, dc.getHeight()/3, Graphics.FONT_XTINY, tm, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+28, Graphics.FONT_TINY, tp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2, (dc.getHeight()/3)+48, Graphics.FONT_XTINY, _weatherStore.freshnessLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------- WEATHER PAGE ----------

    function drawWeatherPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var cx = (w/2).toNumber();
        var cy = (h/2).toNumber();
        var r  = (w < h ? w : h)/2 - 8;

        var s = _weatherStore.getSnapshot();
        var c = s[:current];

        // Round safe area reference rings
        dc.setColor(0x39E7, Graphics.COLOR_BLACK);
        dc.drawCircle(cx, cy, r-2);
        dc.drawCircle(cx, cy, r-18);

        // Header
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var timeText = Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
        var tempText = c[:tempC] == null ? "--°C" : c[:tempC].format("%.0f") + "°C";
        var dateText = Lang.format("$1$-$2$-$3$", [info.year, info.month.format("%02d"), info.day.format("%02d")]);

        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx-115, cy-r+36, Graphics.FONT_XTINY, timeText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(cx+115, cy-r+36, Graphics.FONT_XTINY, tempText, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx-115, cy-r+56, Graphics.FONT_XTINY, "FEELS LIKE 10°", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(cx-115, cy-r+76, Graphics.FONT_XTINY, c[:narrativeText], Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(cx-115, cy-r+96, Graphics.FONT_XTINY, dateText, Graphics.TEXT_JUSTIFY_LEFT);

        // moon indicator
        drawMoon(dc, cx+130, cy-r+92, 8);

        // Side rails (fit round shape)
        drawSideRail(dc, cx-r+42, cy-40, 12, 170, _healthStore.getHeartRate(), 200, 0xF800, "HR");
        drawSideRail(dc, cx+r-42, cy-40, 12, 170, _healthStore.getSpO2(), 100, 0x07FF, "O2");

        // Chart in middle
        _chartRenderer.drawHourlyChart(dc, cx-170, cy-110, 340, 180, s[:hourly]);

        // Bottom daily strip (no inner grid)
        _chartRenderer.drawDailyStripNoGrid(dc, cx-170, cy+92, 340, 70, s[:daily]);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy+r-14, Graphics.FONT_XTINY, "GeoMet V4.2 Outdoor Weather", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------- ASTRO PAGE ----------

    function drawAstroPage(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var cx = (w/2).toNumber();
        var cy = (h/2).toNumber();
        var r  = (w < h ? w : h)/2 - 8;

        var a = _astroStore.getSnapshot();

        dc.setColor(0x39E7, Graphics.COLOR_BLACK);
        dc.drawCircle(cx, cy, r-2);
        dc.drawCircle(cx, cy, r-18);

        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy-r+38, Graphics.FONT_XTINY, "STARGAZING NIGHT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy-r+58, Graphics.FONT_XTINY, "Low cloud + dark window after 22:30", Graphics.TEXT_JUSTIFY_CENTER);

        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateText = Lang.format("$1$-$2$-$3$", [info.year, info.month.format("%02d"), info.day.format("%02d")]);
        dc.drawText(cx-120, cy-r+84, Graphics.FONT_XTINY, dateText, Graphics.TEXT_JUSTIFY_LEFT);
        drawMoon(dc, cx+105, cy-r+82, 9);

        // main astro panel
        dc.setColor(0x39E7, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(cx-145, cy-78, 290, 150, 14);

        // stars
        drawStars(dc, cx, cy-10);

        // score ring
        drawScoreRing(dc, cx, cy-5, 34, a[:stargazingScore]);

        // metrics
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        drawKV(dc, cx-130, cy+20, "Moon", a[:moonPhase] + " " + a[:moonIllumPct].format("%.0f") + "%");
        drawKV(dc, cx-130, cy+36, "Sunset", a[:sunset]);
        drawKV(dc, cx-130, cy+52, "Sunrise", a[:sunrise]);
        drawKV(dc, cx-130, cy+68, "Astro End", a[:astroTwilightEnd]);

        drawKV(dc, cx+5, cy+20, "Cloud", a[:cloudPct].format("%.0f") + "%");
        drawKV(dc, cx+5, cy+36, "Seeing", a[:seeingScore].format("%.0f"));
        drawKV(dc, cx+5, cy+52, "Transp.", a[:transparencyScore].format("%.0f"));
        drawKV(dc, cx+5, cy+68, "Wind", "9 km/h");

        // bottom no-grid time strip
        _chartRenderer.drawAstroTimelineNoGrid(dc, cx-170, cy+102, 340, 56, ["22h","00h","02h","04h","06h"], [22,18,14,20,28]);

        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy+r-14, Graphics.FONT_XTINY, "GeoMet V4.2 Stargazing", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------- helpers ----------

    function drawSideRail(dc as Dc, x as Number, y as Number, bw as Number, bh as Number, val as Number or Null, maxv as Number, col as Number, lbl as String) as Void {
        dc.setColor(0x39E7, Graphics.COLOR_BLACK);
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
        dc.drawText(x + bw/2, y-10, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawMoon(dc as Dc, x as Number, y as Number, r as Number) as Void {
        dc.setColor(0xFFDF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x+3, y, r);
    }

    function drawStars(dc as Dc, cx as Number, cy as Number) as Void {
        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx-70, cy-35, 1);
        dc.fillCircle(cx-35, cy-12, 1);
        dc.fillCircle(cx-10, cy+8, 1);
        dc.fillCircle(cx+24, cy-26, 1);
        dc.fillCircle(cx+58, cy-40, 1);
        dc.fillCircle(cx+40, cy+16, 1);
    }

    function drawScoreRing(dc as Dc, cx as Number, cy as Number, r as Number, score as Number) as Void {
        dc.setColor(0x39E7, Graphics.COLOR_BLACK);
        dc.drawCircle(cx, cy, r);
        dc.setColor(0x07E0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy-6, Graphics.FONT_SMALL, score.format("%.0f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy+12, Graphics.FONT_XTINY, "SKY SCORE", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawKV(dc as Dc, x as Number, y as Number, k as String, v as String) as Void {
        dc.drawText(x, y, Graphics.FONT_XTINY, k + ":", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x+45, y, Graphics.FONT_XTINY, v, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
    }
}
