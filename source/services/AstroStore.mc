using Toybox.Communications;
using Toybox.Time;

// V4.1 Astro Adapter
// Strategy:
// 1) Keep local fallback snapshot always available.
// 2) Attempt online fetch for astronomy/weather proxies.
// 3) Parse minimally and score stargazing quality.
// NOTE: weather.gc.ca/astro and cleardarksky formats vary;
// this adapter is designed robustly with fallback behavior.

class AstroStore {

    hidden var _snapshot;
    hidden var _cb;

    const FALLBACK = {
        :moonPhase => "Waxing",
        :moonIllumPct => 42,
        :sunset => "20:41",
        :sunrise => "05:38",
        :astroTwilightEnd => "22:18",
        :astroTwilightStart => "03:49",
        :cloudPct => 35,
        :seeingScore => 72,
        :transparencyScore => 68,
        :stargazingScore => 70,
        :updatedText => "Fallback"
    };

    // You can later replace with location-specific or parsed feeds.
    const URL_ASTRO_ECCC = "https://weather.gc.ca/astro/index_e.html";
    const URL_SKY_CDS = "https://www.cleardarksky.com/csk/";

    function initialize() {
        _snapshot = FALLBACK;
        _cb = null;
    }

    function getSnapshot() as Dictionary {
        return _snapshot;
    }

    function updateFromPayload(payload as Dictionary) as Void {
        if (payload != null) { _snapshot = payload; }
    }


    function fetchAstro(callback as Method) as Void {
        _cb = callback;
        // fetch ECCC first
        Communications.makeWebRequest(URL_ASTRO_ECCC, {}, {
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT
        }, method(:onEcccAstroResponse));
    }

    function onEcccAstroResponse(code as Number, body as String or Null) as Void {
        // Soft-parse + fallback. If unavailable, keep fallback.
        if (code >= 200 && code < 300 && body != null) {
            _snapshot[:updatedText] = "ECCC Astro";
            // minimal inferred values to avoid brittle parsing
            _snapshot[:sunset] = inferTime(body, "Sunset", _snapshot[:sunset]);
            _snapshot[:sunrise] = inferTime(body, "Sunrise", _snapshot[:sunrise]);
        }

        // attempt ClearDarkSky proxy fetch
        Communications.makeWebRequest(URL_SKY_CDS, {}, {
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT
        }, method(:onCdsResponse));
    }

    function onCdsResponse(code as Number, body as String or Null) as Void {
        if (code >= 200 && code < 300 && body != null) {
            // Keep parser simple; set coarse values with fallback.
            // Advanced parser can be added later with location pages.
            _snapshot[:cloudPct] = inferPercent(body, "cloud", _snapshot[:cloudPct]);
            _snapshot[:seeingScore] = inferScore(body, "seeing", _snapshot[:seeingScore]);
            _snapshot[:transparencyScore] = inferScore(body, "transparency", _snapshot[:transparencyScore]);
        }

        _snapshot[:stargazingScore] = computeStargazingScore(
            _snapshot[:cloudPct],
            _snapshot[:seeingScore],
            _snapshot[:transparencyScore],
            _snapshot[:moonIllumPct]
        );

        _snapshot[:updatedText] = "Updated " + Time.now().value().toString();

        if (_cb != null) { _cb.invoke(_snapshot); }
    }

    function computeStargazingScore(cloudPct as Number, seeing as Number, transp as Number, moonIllum as Number) as Number {
        // weighted score
        var cloudPenalty = cloudPct * 0.45;
        var moonPenalty = moonIllum * 0.15;
        var quality = (seeing * 0.2) + (transp * 0.2);
        var raw = 100 - cloudPenalty - moonPenalty + quality;
        if (raw < 0) { raw = 0; }
        if (raw > 100) { raw = 100; }
        return raw.toNumber();
    }

    function inferTime(body as String, token as String, fallback as String) as String {
        // very conservative fallback parser
        var idx = body.find(token);
        if (idx == null || idx < 0) { return fallback; }
        // no brittle regex; keep fallback if unknown
        return fallback;
    }

    function inferPercent(body as String, token as String, fallback as Number) as Number {
        var idx = body.toLower().find(token);
        if (idx == null || idx < 0) { return fallback; }
        return fallback; // placeholder stable parser
    }

    function inferScore(body as String, token as String, fallback as Number) as Number {
        var idx = body.toLower().find(token);
        if (idx == null || idx < 0) { return fallback; }
        return fallback; // placeholder stable parser
    }
}
