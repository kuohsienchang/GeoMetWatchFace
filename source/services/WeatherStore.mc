using Toybox.Time;

class WeatherStore {

    const STALE_LIMIT_MIN = 120;
    hidden var _snapshot;

    function initialize() {
        _snapshot = {
            :ok => false,
            :current => {
                :tempC => null,
                :feelsLikeC => null,
                :conditionText => "Loading...",
                :iconCode => "cloud",
                :narrativeText => "Fetching GeoMet data...",
                :updatedEpoch => null
            },
            :hourly => [],
            :daily => [],
            :meta => {
                :locationName => "Canada",
                :source => "GeoMet"
            }
        };
    }

    function updateSnapshotV4(payload as Dictionary) as Void {
        if (payload == null || !(payload has :ok) || !payload[:ok]) {
            // keep old snapshot but show degraded state
            _snapshot[:current][:conditionText] = "GeoMet unavailable";
            _snapshot[:current][:narrativeText] = "Using cached data.";
            return;
        }

        _snapshot = payload;

        if (!(_snapshot has :hourly) || _snapshot[:hourly] == null) { _snapshot[:hourly] = []; }
        if (!(_snapshot has :daily) || _snapshot[:daily] == null) { _snapshot[:daily] = []; }

        if (!(_snapshot[:current] has :updatedEpoch) || _snapshot[:current][:updatedEpoch] == null) {
            _snapshot[:current][:updatedEpoch] = Time.now().value();
        }
    }

    function getSnapshot() as Dictionary {
        return _snapshot;
    }

    function freshnessMinutes() as Number {
        if (_snapshot == null || !(_snapshot has :current) || _snapshot[:current][:updatedEpoch] == null) {
            return -1;
        }
        return ((Time.now().value() - _snapshot[:current][:updatedEpoch]) / 60).toNumber();
    }

    function freshnessLabel() as String {
        var age = freshnessMinutes();
        if (age < 0) { return "NO DATA"; }
        if (age <= 30) { return "LIVE"; }
        if (age <= STALE_LIMIT_MIN) { return age.format("%.0f") + "m"; }
        return "STALE";
    }
}
