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
