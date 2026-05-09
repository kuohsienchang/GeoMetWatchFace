using Toybox.Time;

class WeatherStore {
    const STALE_MINUTES_DEFAULT = 120;
    hidden var _snapshot;

    function initialize() {
        _snapshot = {
            :ok => false,
            :current => {
                :tempC=>null,:feelsLikeC=>null,:conditionText=>"Loading...",:iconCode=>"unknown",
                :humidityPct=>null,:windKmh=>null,:windDirDeg=>null,:pressureKpa=>null,
                :narrativeText=>"Fetching GeoMet data...",:updatedEpoch=>null
            },
            :hourly => [],
            :daily => [],
            :meta => {:locationName=>"Canada", :source=>"GeoMet"}
        };
    }

    function getSnapshot() as Dictionary { return _snapshot; }

    function updateSnapshotV2(payload as Dictionary) as Void {
        if (payload == null || !(payload has :ok) || !payload[:ok]) {
            _snapshot[:current][:conditionText] = "GeoMet unavailable";
            _snapshot[:current][:narrativeText] = "Using cached weather.";
            return;
        }

        _snapshot = payload;
        if (!(_snapshot has :hourly) || _snapshot[:hourly] == null) { _snapshot[:hourly] = []; }
        if (!(_snapshot has :daily)  || _snapshot[:daily]  == null) { _snapshot[:daily]  = []; }
        if (!(_snapshot[:current] has :updatedEpoch) || _snapshot[:current][:updatedEpoch] == null) {
            _snapshot[:current][:updatedEpoch] = Time.now().value();
        }
    }

    function freshnessMinutes() as Number {
        if (!(_snapshot has :current) || _snapshot[:current][:updatedEpoch] == null) { return -1; }
        return ((Time.now().value() - _snapshot[:current][:updatedEpoch]) / 60).toNumber();
    }

    function staleStateLabel() as String {
        var age = freshnessMinutes();
        if (age < 0) { return "NO DATA"; }
        if (age <= 30) { return "LIVE"; }
        if (age <= STALE_MINUTES_DEFAULT) { return age.format("%.0f") + "m"; }
        return "STALE";
    }
}
