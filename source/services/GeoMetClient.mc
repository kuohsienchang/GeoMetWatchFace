using Toybox.Communications;
using Toybox.Time;

class GeoMetClient {

    // NOTE: these are baseline endpoints; refine location filters later.
    const URL_CURRENT = "https://api.weather.gc.ca/collections/climate-hourly/items?f=json&limit=1";
    const URL_HOURLY  = "https://api.weather.gc.ca/collections/climate-hourly/items?f=json&limit=24";
    const URL_DAILY   = "https://api.weather.gc.ca/collections/climate-daily/items?f=json&limit=5";

    hidden var _cb;
    hidden var _current;
    hidden var _hourly;
    hidden var _daily;

    function initialize() {
        _cb = null;
        _current = null;
        _hourly = [];
        _daily = [];
    }

    function fetchSnapshotV4(cb as Method) as Void {
        _cb = cb;
        _current = null;
        _hourly = [];
        _daily = [];
        fetchCurrent();
    }

    function fetchCurrent() as Void {
        Communications.makeWebRequest(URL_CURRENT, {}, httpOptions(), method(:onCurrent));
    }

    function fetchHourly() as Void {
        Communications.makeWebRequest(URL_HOURLY, {}, httpOptions(), method(:onHourly));
    }

    function fetchDaily() as Void {
        Communications.makeWebRequest(URL_DAILY, {}, httpOptions(), method(:onDaily));
    }

    function onCurrent(code as Number, body as Dictionary or Null) as Void {
        if (!(code >= 200 && code < 300) || body == null) {
            finish({ :ok => false, :error => "Current HTTP " + code });
            return;
        }

        var f = firstFeature(body);
        if (f == null || !(f has :properties)) {
            finish({ :ok => false, :error => "Current payload missing" });
            return;
        }

        var p = f[:properties];
        var t = safeNum(p, :TEMP, 0.0);

        _current = {
            :tempC => t,
            :feelsLikeC => safeNum(p, :WIND_CHILL, t),
            :conditionText => "Observed",
            :iconCode => normalizeIcon(p),
            :narrativeText => "Analyzing hourly trend...",
            :updatedEpoch => Time.now().value()
        };

        fetchHourly();
    }

    function onHourly(code as Number, body as Dictionary or Null) as Void {
        _hourly = [];
        if (code >= 200 && code < 300 && body != null) {
            var arr = featureList(body);
            var i = 0;
            while (i < arr.size() && i < 24) {
                var row = arr[i];
                if (row != null && row has :properties) {
                    var p = row[:properties];
                    _hourly.add({
                        :epoch => Time.now().value() + (i * 3600),
                        :tempC => safeNum(p, :TEMP, _current[:tempC]),
                        :precipMm => safeNum(p, :TOTAL_PRECIPITATION, 0.0),
                        :windKmh => safeNum(p, :WIND_SPEED, 0.0),
                        :iconCode => normalizeIcon(p)
                    });
                }
                i += 1;
            }
        }

        fetchDaily();
    }

    function onDaily(code as Number, body as Dictionary or Null) as Void {
        _daily = [];
        if (code >= 200 && code < 300 && body != null) {
            var arr = featureList(body);
            var i = 0;
            while (i < arr.size() && i < 5) {
                var row = arr[i];
                if (row != null && row has :properties) {
                    var p = row[:properties];
                    _daily.add({
                        :dayLabel => dayLabel(i),
                        :minC => safeNum(p, :MIN_TEMPERATURE, null),
                        :maxC => safeNum(p, :MAX_TEMPERATURE, null),
                        :iconCode => normalizeIcon(p)
                    });
                }
                i += 1;
            }
        }

        _current[:narrativeText] = narrativeFromHourly(_hourly);

        finish({
            :ok => true,
            :current => _current,
            :hourly => _hourly,
            :daily => _daily,
            :meta => {
                :locationName => "GeoMet Canada",
                :source => "GeoMet"
            }
        });
    }

    function narrativeFromHourly(hourly as Array) as String {
        if (hourly == null || hourly.size() == 0) { return "Stable conditions."; }

        var wet = 0.0;
        var i = 0;
        while (i < hourly.size()) {
            var p = hourly[i][:precipMm];
            if (p != null && p > wet) { wet = p; }
            i += 1;
        }

        if (wet >= 2.0) { return "Rain likely in next hours."; }
        if (wet >= 0.3) { return "Light precipitation possible."; }
        return "Trend stable through day.";
    }

    function normalizeIcon(p as Dictionary) as String {
        // Basic icon mapping (upgrade with official codes later)
        var precip = safeNum(p, :TOTAL_PRECIPITATION, 0.0);
        var temp = safeNum(p, :TEMP, 1.0);

        if (precip > 0.2 && temp <= 0) { return "snow"; }
        if (precip > 0.2) { return "rain"; }
        return "cloud";
    }

    function dayLabel(i as Number) as String {
        if (i == 0) { return "TOD"; }
        if (i == 1) { return "MON"; }
        if (i == 2) { return "TUE"; }
        if (i == 3) { return "WED"; }
        return "THU";
    }

    function httpOptions() as Dictionary {
        return {
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Accept" => "application/geo+json, application/json" }
        };
    }

    function featureList(body as Dictionary) as Array {
        if (body has :features && body[:features] != null) { return body[:features]; }
        return [];
    }

    function firstFeature(body as Dictionary) as Dictionary or Null {
        var arr = featureList(body);
        return arr.size() > 0 ? arr[0] : null;
    }

    function safeNum(p as Dictionary, k as Symbol, fallback as Number or Null) as Number or Null {
        if (!(p has k) || p[k] == null) { return fallback; }
        var v = p[k];
        return v instanceof Number ? v : fallback;
    }

    function finish(payload as Dictionary) as Void {
        if (_cb != null) { _cb.invoke(payload); }
    }
}
