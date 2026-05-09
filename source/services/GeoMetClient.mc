using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

class GeoMetClient {
    const CURRENT_URL = "https://api.weather.gc.ca/collections/climate-hourly/items?f=json&limit=1";
    const HOURLY_URL  = "https://api.weather.gc.ca/collections/climate-hourly/items?f=json&limit=24";
    const DAILY_URL   = "https://api.weather.gc.ca/collections/climate-daily/items?f=json&limit=5";

    hidden var _callback;
    hidden var _currentData;
    hidden var _hourlyData;
    hidden var _dailyData;

    function initialize() {
        _callback = null;
        _currentData = null;
        _hourlyData = null;
        _dailyData = null;
    }

    function fetchSnapshotV2(callback as Method) as Void {
        _callback = callback;
        _currentData = null;
        _hourlyData = [];
        _dailyData = [];
        fetchCurrent();
    }

    function fetchCurrent() as Void {
        Communications.makeWebRequest(CURRENT_URL, {}, defaultHttpOptions(), method(:onCurrentResponse));
    }

    function fetchHourly24() as Void {
        Communications.makeWebRequest(HOURLY_URL, {}, defaultHttpOptions(), method(:onHourlyResponse));
    }

    function fetchDaily5() as Void {
        Communications.makeWebRequest(DAILY_URL, {}, defaultHttpOptions(), method(:onDailyResponse));
    }

    function onCurrentResponse(code as Number, body as Dictionary or Null) as Void {
        if (!isHttpOk(code) || body == null) {
            finish({:ok=>false,:error=>"Current fetch failed: HTTP "+code});
            return;
        }

        var f = firstFeature(body);
        if (f == null || !(f has :properties)) {
            finish({:ok=>false,:error=>"Current payload missing properties"});
            return;
        }

        var p = f[:properties];
        var t = safeNum(p, :TEMP, null);

        _currentData = {
            :tempC         => t == null ? 0.0 : t,
            :feelsLikeC    => safeNum(p, :WIND_CHILL, t),
            :conditionText => "Observed",
            :iconCode      => normalizeIconCode(p),
            :humidityPct   => safeNum(p, :RELATIVE_HUMIDITY, null),
            :windKmh       => safeNum(p, :WIND_SPEED, null),
            :windDirDeg    => safeNum(p, :WIND_DIRECTION, null),
            :pressureKpa   => safeNum(p, :STATION_PRESSURE, null),
            :locationName  => safeStr(p, :CLIMATE_IDENTIFIER, "GeoMet"),
            :updatedEpoch  => Time.now().value()
        };

        fetchHourly24();
    }

    function onHourlyResponse(code as Number, body as Dictionary or Null) as Void {
        _hourlyData = [];
        if (isHttpOk(code) && body != null) {
            var arr = featureList(body);
            var n = arr.size();
            var i = 0;
            while (i < n && i < 24) {
                var f = arr[i];
                if (f != null && f has :properties) {
                    var p = f[:properties];
                    _hourlyData.add({
                        :epoch    => Time.now().value() + (i * 3600),
                        :tempC    => safeNum(p, :TEMP, _currentData[:tempC]),
                        :popPct   => safeNum(p, :PROBABILITY_OF_PRECIPITATION, 0.0),
                        :precipMm => safeNum(p, :TOTAL_PRECIPITATION, 0.0),
                        :iconCode => normalizeIconCode(p)
                    });
                }
                i += 1;
            }
        }
        fetchDaily5();
    }

    function onDailyResponse(code as Number, body as Dictionary or Null) as Void {
        _dailyData = [];
        if (isHttpOk(code) && body != null) {
            var arr = featureList(body);
            var n = arr.size();
            var i = 0;
            while (i < n && i < 5) {
                var f = arr[i];
                if (f != null && f has :properties) {
                    var p = f[:properties];
                    _dailyData.add({
                        :dayLabel => dayLabelFromOffset(i),
                        :minC     => safeNum(p, :MIN_TEMPERATURE, null),
                        :maxC     => safeNum(p, :MAX_TEMPERATURE, null),
                        :iconCode => normalizeIconCode(p)
                    });
                }
                i += 1;
            }
        }
        composeAndFinish();
    }

    function composeAndFinish() as Void {
        if (_currentData == null) {
            finish({:ok=>false,:error=>"No current data"});
            return;
        }

        var payload = {
            :ok => true,
            :current => {
                :tempC         => _currentData[:tempC],
                :feelsLikeC    => _currentData[:feelsLikeC],
                :conditionText => _currentData[:conditionText],
                :iconCode      => _currentData[:iconCode],
                :humidityPct   => _currentData[:humidityPct],
                :windKmh       => _currentData[:windKmh],
                :windDirDeg    => _currentData[:windDirDeg],
                :pressureKpa   => _currentData[:pressureKpa],
                :narrativeText => composeNarrative(_currentData, _hourlyData),
                :updatedEpoch  => _currentData[:updatedEpoch]
            },
            :hourly => _hourlyData,
            :daily  => _dailyData,
            :meta   => {:locationName=>_currentData[:locationName], :source=>"GeoMet"}
        };

        finish(payload);
    }

    function composeNarrative(current as Dictionary, hourly as Array or Null) as String {
        var maxPop = 0.0;
        if (hourly != null) {
            var i = 0;
            while (i < hourly.size()) {
                var row = hourly[i];
                if (row != null && row has :popPct && row[:popPct] != null && row[:popPct] > maxPop) {
                    maxPop = row[:popPct];
                }
                i += 1;
            }
        }

        if (maxPop >= 60) { return "Precip likely (" + maxPop.format("%.0f") + "%)."; }
        if (maxPop >= 30) { return "Light precip possible."; }
        return "Stable conditions.";
    }

    function defaultHttpOptions() as Dictionary {
        return {
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers      => {"Accept"=>"application/geo+json, application/json"}
        };
    }

    function isHttpOk(code as Number) as Boolean {
        return code >= 200 && code < 300;
    }

    function firstFeature(body as Dictionary) as Dictionary or Null {
        var arr = featureList(body);
        return arr.size() > 0 ? arr[0] : null;
    }

    function featureList(body as Dictionary) as Array {
        if (body has :features && body[:features] != null) { return body[:features]; }
        return [];
    }

    function safeNum(props as Dictionary, key as Symbol, fallback as Number or Null) as Number or Null {
        if (!(props has key) || props[key] == null) { return fallback; }
        var v = props[key];
        return v instanceof Number ? v : fallback;
    }

    function safeStr(props as Dictionary, key as Symbol, fallback as String) as String {
        if (!(props has key) || props[key] == null) { return fallback; }
        return props[key].toString();
    }

    function dayLabelFromOffset(i as Number) as String {
        if (i == 0) { return "Today"; }
        if (i == 1) { return "Tomorrow"; }
        return "D+" + i;
    }

    function normalizeIconCode(props as Dictionary) as String {
        if (props has :TOTAL_PRECIPITATION && props[:TOTAL_PRECIPITATION] != null && props[:TOTAL_PRECIPITATION] > 0) { return "rain"; }
        return "cloud";
    }

    function finish(payload as Dictionary) as Void {
        if (_callback != null) { _callback.invoke(payload); }
    }
}
