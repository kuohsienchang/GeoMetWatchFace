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
