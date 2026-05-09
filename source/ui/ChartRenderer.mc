using Toybox.Graphics;

class ChartRenderer {
    const COLOR_GRID = 0x5AEB;
    const COLOR_TEMP = 0xF81F;
    const COLOR_BAR  = 0x07EF;

    function initialize() {}

    function drawHourlyChart(dc as Dc, x as Number, y as Number, w as Number, h as Number, hourly as Array) as Void {
        dc.setColor(COLOR_GRID, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);

        if (hourly == null || hourly.size() < 2) { return; }

        var n = hourly.size();
        var maxP = 0.1;
        var minT = 999.0;
        var maxT = -999.0;

        var i = 0;
        while (i < n) {
            var row = hourly[i];
            var p = (row has :precipMm && row[:precipMm] != null) ? row[:precipMm] : 0.0;
            var t = (row has :tempC && row[:tempC] != null) ? row[:tempC] : 0.0;
            if (p > maxP) { maxP = p; }
            if (t < minT) { minT = t; }
            if (t > maxT) { maxT = t; }
            i += 1;
        }
        if (maxT <= minT) { maxT = minT + 1.0; }

        // bars
        dc.setColor(COLOR_BAR, Graphics.COLOR_TRANSPARENT);
        var bw = (w / n).toNumber();
        i = 0;
        while (i < n) {
            var p2 = (hourly[i] has :precipMm && hourly[i][:precipMm] != null) ? hourly[i][:precipMm] : 0.0;
            var bh = ((p2 / maxP) * (h * 0.35)).toNumber();
            var bx = x + (i * bw);
            var by = y + h - bh;
            if (bh > 0) { dc.fillRectangle(bx, by, bw > 2 ? bw - 1 : 1, bh); }
            i += 1;
        }

        // temp line
        dc.setColor(COLOR_TEMP, Graphics.COLOR_TRANSPARENT);
        var px0 = x;
        var py0 = y + h - mapT(hourly[0], minT, maxT, h);
        i = 1;
        while (i < n) {
            var px1 = x + ((w * i) / (n - 1));
            var py1 = y + h - mapT(hourly[i], minT, maxT, h);
            dc.drawLine(px0, py0, px1, py1);
            px0 = px1; py0 = py1;
            i += 1;
        }
    }

    function drawDailyStrip(dc as Dc, x as Number, y as Number, w as Number, h as Number, daily as Array) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);
        if (daily == null || daily.size() == 0) { return; }

        var c = daily.size();
        if (c > 5) { c = 5; }
        var cw = (w / c).toNumber();

        var i = 0;
        while (i < c) {
            var d = daily[i];
            var cx = x + (i * cw) + (cw / 2);
            var label = d has :dayLabel ? d[:dayLabel] : ("D+" + i);
            var minTxt = (d has :minC && d[:minC] != null) ? d[:minC].format("%.0f") : "--";
            var maxTxt = (d has :maxC && d[:maxC] != null) ? d[:maxC].format("%.0f") : "--";
            dc.drawText(cx, y + 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, y + h - 14, Graphics.FONT_XTINY, minTxt + "/" + maxTxt, Graphics.TEXT_JUSTIFY_CENTER);
            i += 1;
        }
    }

    function mapT(row as Dictionary, minT as Number, maxT as Number, h as Number) as Number {
        var t = (row has :tempC && row[:tempC] != null) ? row[:tempC] : minT;
        var v = (t - minT) / (maxT - minT);
        return (v * (h * 0.65)).toNumber() + (h * 0.20);
    }
}
