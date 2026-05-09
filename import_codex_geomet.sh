#!/usr/bin/env bash
set -euo pipefail

mkdir -p source/services resources/{drawables,layouts,strings} docs/previews docs/release-candidate

cat > manifest.xml <<'EOF'
<?xml version="1.0"?>
<iq:manifest version="3" xmlns:iq="http://www.garmin.com/xml/connectiq">
  <iq:application entry="GeoMetWatchFaceApp" id="com.geomet.watchface" launcherIcon="@Drawables.LauncherIcon" minSdkVersion="3.2.0" name="@Strings.AppName" type="watchface" version="0.1.0">
    <iq:products>
      <iq:product id="venu3"/>
      <iq:product id="forerunner255"/>
      <iq:product id="fenix7"/>
    </iq:products>
    <iq:permissions>
      <iq:uses-permission id="Positioning"/>
      <iq:uses-permission id="Communications"/>
      <iq:uses-permission id="PersistedContent"/>
    </iq:permissions>
    <iq:languages><iq:language>eng</iq:language></iq:languages>
    <iq:barrels/>
  </iq:application>
</iq:manifest>
EOF

cat > monkey.jungle <<'EOF'
project.manifest = manifest.xml
base.resourcePath = resources
base.sourcePath = source
compiler.options = -O2
EOF

cat > source/GeoMetWatchFaceApp.mc <<'EOF'
using Toybox.Application;
using Toybox.WatchUi;
class GeoMetWatchFaceApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [ new GeoMetWatchFaceView(), new GeoMetWatchFaceDelegate() ]; }
}
EOF

cat > source/GeoMetWatchFaceDelegate.mc <<'EOF'
using Toybox.WatchUi;
class GeoMetWatchFaceDelegate extends WatchUi.BehaviorDelegate {}
EOF

cat > source/services/GeoMetClient.mc <<'EOF'
using Toybox.Communications;
class GeoMetClient {
    const CURRENT_URL = "https://api.weather.gc.ca/collections/climate-hourly/items?f=json&limit=1";
    const DAILY_URL   = "https://api.weather.gc.ca/collections/climate-daily/items?f=json&limit=1";
    hidden var _delegate; hidden var _currentPayload;
    function initialize() { _currentPayload = null; }
    function fetchLatest(delegate as Method) as Void {
        _delegate = delegate; _currentPayload = null;
        var options = {:responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,:headers=>{"Accept"=>"application/geo+json, application/json"}};
        Communications.makeWebRequest(CURRENT_URL, {}, options, method(:onCurrentResponse));
    }
    function onCurrentResponse(code as Number, body as Dictionary or Null) as Void {
        if (code < 200 || code >= 300 || body == null) { finish({:ok=>false,:error=>"Current HTTP "+code}); return; }
        var feature = firstFeature(body); if (feature == null || !(feature has :properties)) { finish({:ok=>false,:error=>"Missing current properties"}); return; }
        var props = feature[:properties];
        _currentPayload = {:temperatureC=>(toNumber(props,:TEMP)==null?0.0:toNumber(props,:TEMP)),:condition=>"Observed",:sourceTime=>(props has :LOCAL_DATE?props[:LOCAL_DATE].toString():"unknown"),:humidity=>toNumber(props,:RELATIVE_HUMIDITY),:windKmh=>toNumber(props,:WIND_SPEED),:precipMm=>toNumber(props,:TOTAL_PRECIPITATION)};
        var options = {:responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,:headers=>{"Accept"=>"application/geo+json, application/json"}};
        Communications.makeWebRequest(DAILY_URL, {}, options, method(:onDailyResponse));
    }
    function onDailyResponse(code as Number, body as Dictionary or Null) as Void {
        if (_currentPayload == null) { finish({:ok=>false,:error=>"Current payload missing"}); return; }
        var minT = null; var maxT = null; var forecastText = "Forecast unavailable";
        if (code >= 200 && code < 300 && body != null) {
            var feature = firstFeature(body);
            if (feature != null && feature has :properties) {
                var props = feature[:properties]; minT = toNumber(props,:MIN_TEMPERATURE); maxT = toNumber(props,:MAX_TEMPERATURE);
                if (minT != null && maxT != null) { forecastText = "Today "+minT.format("%.0f")+"°/"+maxT.format("%.0f")+"°"; }
            }
        }
        var richText = "Now "+_currentPayload[:temperatureC].format("%.0f")+"°C "+_currentPayload[:condition]+" | "+forecastText;
        finish({:ok=>true,:temperatureC=>_currentPayload[:temperatureC],:condition=>_currentPayload[:condition],:sourceTime=>_currentPayload[:sourceTime],:humidity=>_currentPayload[:humidity],:windKmh=>_currentPayload[:windKmh],:precipMm=>_currentPayload[:precipMm],:minTempC=>minT,:maxTempC=>maxT,:richWeatherText=>richText});
    }
    function finish(payload as Dictionary) as Void { if (_delegate != null) { _delegate.invoke(payload); } }
    function firstFeature(body as Dictionary) as Dictionary or Null { return (body has :features && body[:features] != null && body[:features].size() > 0) ? body[:features][0] : null; }
    function toNumber(props as Dictionary, key as Symbol) as Number or Null { return (!(props has key) || props[key]==null || !(props[key] instanceof Number)) ? null : props[key]; }
}
EOF

cat > source/services/WeatherStore.mc <<'EOF'
using Toybox.Time;
class WeatherStore {
    hidden var _snapshot;
    function initialize() {
        _snapshot = {:temperatureC=>null,:condition=>"Loading...",:ageMinutes=>-1,:sourceTime=>"n/a",:humidity=>null,:windKmh=>null,:precipMm=>null,:minTempC=>null,:maxTempC=>null,:richWeatherText=>"Now -- | Forecast loading..."};
    }
    function getSnapshot() as Dictionary { return _snapshot; }
    function updateFromGeoMet(payload as Dictionary) as Void {
        if (!(payload has :ok) || !payload[:ok]) { _snapshot[:condition]="GeoMet unavailable"; _snapshot[:richWeatherText]="Now unavailable | Forecast unavailable"; return; }
        _snapshot[:temperatureC]=payload[:temperatureC]; _snapshot[:condition]=payload[:condition]; _snapshot[:sourceTime]=payload[:sourceTime];
        _snapshot[:humidity]=payload[:humidity]; _snapshot[:windKmh]=payload[:windKmh]; _snapshot[:precipMm]=payload[:precipMm];
        _snapshot[:minTempC]=payload[:minTempC]; _snapshot[:maxTempC]=payload[:maxTempC]; _snapshot[:richWeatherText]=payload[:richWeatherText];
        _snapshot[:ageMinutes]=0; _snapshot[:updatedEpoch]=Time.now().value();
    }
    function ageMinutes() as Number { return !(_snapshot has :updatedEpoch) ? -1 : ((Time.now().value()-_snapshot[:updatedEpoch])/60).toNumber(); }
}
EOF

cat > source/GeoMetWatchFaceView.mc <<'EOF'
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
EOF

cat > resources/strings/strings.xml <<'EOF'
<strings><string id="AppName">GeoMet Weather Face</string></strings>
EOF
cat > resources/drawables/drawables.xml <<'EOF'
<drawables><bitmap id="LauncherIcon" filename="launcher_icon.png"/></drawables>
EOF
cat > resources/layouts/layouts.xml <<'EOF'
<layouts><layout id="WatchFaceLayout"><label id="Placeholder" x="50%" y="50%" justification="center" font="Graphics.FONT_TINY" color="Graphics.COLOR_WHITE">GeoMet</label></layout></layouts>
EOF

python - <<'PY'
from PIL import Image
from pathlib import Path
Path("resources/drawables").mkdir(parents=True,exist_ok=True)
Image.new("RGB",(80,80),(35,60,120)).save("resources/drawables/launcher_icon.png")
PY

cat > docs/release-candidate/README.md <<'EOF'
# Release Candidate Screen Pack (v0.1.0-rc1)

1. `rc-01-fenix-day.png` — Fenix MIP day theme.
2. `rc-02-fenix-night.png` — Fenix MIP night theme.
3. `rc-03-venu-day.png` — Venu AMOLED day theme.
4. `rc-04-venu-night.png` — Venu AMOLED night theme.
5. `rc-contact-sheet.png` — Combined 2x2 contact sheet.
EOF

cat > README.md <<'EOF'
# GeoMetWatchFace
Garmin WatchFace powered by CMC GeoMet
EOF

echo "Import script completed."
