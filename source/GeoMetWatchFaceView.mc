using Toybox.Graphics; using Toybox.Lang; using Toybox.Time; using Toybox.WatchUi;
class GeoMetWatchFaceView extends WatchUi.WatchFace {
    hidden var _weatherStore; hidden var _geoMetClient; hidden var _fetchPending;
    function initialize(){ WatchFace.initialize(); _weatherStore=new WeatherStore(); _geoMetClient=new GeoMetClient(); _fetchPending=false; }
    function onLayout(dc as Dc) as Void { setLayout(Rez.Layouts.WatchFaceLayout(dc)); }
    function onShow() as Void { if (!_fetchPending) { _fetchPending=true; _geoMetClient.fetchLatest(method(:onWeatherResponse)); } }
    function onWeatherResponse(payload as Dictionary) as Void { _fetchPending=false; _weatherStore.updateFromGeoMet(payload); WatchUi.requestUpdate(); }
    function onUpdate(dc as Dc) as Void {
        var info=Gregorian.info(Time.now(),Time.FORMAT_MEDIUM); var w=_weatherStore.getSnapshot(); w[:ageMinutes]=_weatherStore.ageMinutes();
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        var timeText=Lang.format("$1$:$2$",[info.hour.format("%02d"),info.min.format("%02d")]);
        dc.drawText(dc.getWidth()/2,40,Graphics.FONT_SMALL,timeText,Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2,68,Graphics.FONT_XTINY,Lang.format("$1$-$2$-$3$",[info.year,info.month.format("%02d"),info.day.format("%02d")]),Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2,106,Graphics.FONT_MEDIUM,(w[:temperatureC]==null?"--°C":Lang.format("$1$°C",[w[:temperatureC].format("%.0f")])),Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2,132,Graphics.FONT_TINY,w[:condition],Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth()/2,256,Graphics.FONT_XTINY,w[:richWeatherText],Graphics.TEXT_JUSTIFY_CENTER);
    }
    function onPartialUpdate(dc as Dc) as Void { onUpdate(dc); }
}
