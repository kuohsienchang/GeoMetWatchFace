using Toybox.Graphics;

class ChartRenderer {

    const GRID = 0x39E7;
    const TEMP = 0xF81F;
    const PREC = 0x07FF;
    const WIND = 0xF800;

    function initialize() {}

    function drawHourlyChart(dc as Dc, x as Number, y as Number, w as Number, h as Number, hourly as Array) as Void {
        dc.setColor(GRID, Graphics.COLOR_BLACK);
        dc.drawRectangle(x, y, w, h);

        if (hourly == null || hourly.size() < 2) { return; }

        // chart grid
        var i = 1;
        while (i < 12) {
            var gx = x + (w*i)/12;
            dc.drawLine(gx, y, gx, y+h);
            i += 1;
        }
        var j = 1;
        while (j < 5) {
            var gy = y + (h*j)/5;
            dc.drawLine(x, gy, x+w, gy);
            j += 1;
        }

        drawPrecip(dc, x, y, w, h, hourly);
        drawTemp(dc, x, y, w, h, hourly);
        drawWind(dc, x, y, w, h, hourly);
        drawIcons(dc, x, y, w, h, hourly);
    }

    function drawDailyStripNoGrid(dc as Dc, x as Number, y as Number, w as Number, h as Number, daily as Array) as Void {
        dc.setColor(GRID, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(x, y, w, h, 10);

        if (daily == null || daily.size() == 0) { return; }

        var n = daily.size();
        if (n > 5) { n = 5; }
        var cw = (w / n).toNumber();

        var i = 0;
        while (i < n) {
            var row = daily[i];
            var bx = x + i*cw;
            if (i > 0) {
                dc.drawLine(bx, y+6, bx, y+h-6);
            }

            var day = row has :dayLabel ? row[:dayLabel] : ("D+"+i);
            var mn = row[:minC] == null ? "--" : row[:minC].format("%.0f");
            var mx = row[:maxC] == null ? "--" : row[:maxC].format("%.0f");

            dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx+8, y+8, Graphics.FONT_XTINY, day, Graphics.TEXT_JUSTIFY_LEFT);

            drawIcon(dc, bx+cw-20, y+18, row[:iconCode], 5);

            dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx+8, y+28, Graphics.FONT_XTINY, mn + "°/" + mx + "°", Graphics.TEXT_JUSTIFY_LEFT);

            i += 1;
        }
    }

    function drawAstroTimelineNoGrid(dc as Dc, x as Number, y as Number, w as Number, h as Number, labels as Array, cloud as Array) as Void {
        dc.setColor(GRID, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(x, y, w, h, 10);

        var n = labels.size();
        var cw = (w / n).toNumber();
        var i = 0;
        while (i < n) {
            var bx = x + i*cw;
            if (i > 0) {
                dc.drawLine(bx, y+6, bx, y+h-6);
            }

            dc.setColor(0x7BEF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx+6, y+8, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx+6, y+24, Graphics.FONT_XTINY, "Cloud " + cloud[i].format("%.0f") + "%", Graphics.TEXT_JUSTIFY_LEFT);

            // small moon crescent
            dc.setColor(0xFFDF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx+cw-18, y+18, 5);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx+cw-16, y+18, 5);

            i += 1;
        }
    }

    function drawIcon(dc as Dc, x as Number, y as Number, code as String or Null, r as Number) as Void {
        var c = Graphics.COLOR_WHITE;
        if (code == "sun") { c = Graphics.COLOR_YELLOW; }
        if (code == "rain") { c = Graphics.COLOR_CYAN; }
        if (code == "snow") { c = Graphics.COLOR_LT_GRAY; }
        if (code == "storm") { c = Graphics.COLOR_RED; }

        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        if (code == "rain") {
            dc.drawLine(x-3, y+r+1, x-4, y+r+5);
            dc.drawLine(x+1, y+r+1, x, y+r+5);
        }
        if (code == "snow") {
            dc.drawText(x, y+r+1, Graphics.FONT_XTINY, "*", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawPrecip(dc as Dc, x as Number, y as Number, w as Number, h as Number, arr as Array) as Void {
        var n = arr.size();
        var maxp = 0.1;

        var i = 0;
        while (i < n) {
            var p = arr[i][:precipMm] == null ? 0.0 : arr[i][:precipMm];
            if (p > maxp) { maxp = p; }
            i += 1;
        }

        dc.setColor(PREC, Graphics.COLOR_TRANSPARENT);
        var bw = (w/n).toNumber();

        i = 0;
        while (i < n) {
            var pp = arr[i][:precipMm] == null ? 0.0 : arr[i][:precipMm];
            var bh = ((pp/maxp) * (h*0.30)).toNumber();
            var bx = x + i*bw;
            if (bh > 0) {
                dc.fillRectangle(bx, y+h-bh, bw > 2 ? bw-1 : 1, bh);
            }
            i += 1;
        }
    }

    function drawTemp(dc as Dc, x as Number, y as Number, w as Number, h as Number, arr as Array) as Void {
        var n = arr.size();
        var minT = 999.0;
        var maxT = -999.0;

        var i = 0;
        while (i < n) {
            var t = arr[i][:tempC] == null ? 0.0 : arr[i][:tempC];
            if (t < minT) { minT = t; }
            if (t > maxT) { maxT = t; }
            i += 1;
        }
        if (maxT <= minT) { maxT = minT + 1.0; }

        dc.setColor(TEMP, Graphics.COLOR_TRANSPARENT);

        var px = x;
        var py = y + h - mapT(arr[0], minT, maxT, h);

        i = 1;
        while (i < n) {
            var nx = x + (w*i)/(n-1);
            var ny = y + h - mapT(arr[i], minT, maxT, h);
            dc.drawLine(px, py, nx, ny);
            px = nx; py = ny;
            i += 1;
        }
    }

    function drawWind(dc as Dc, x as Number, y as Number, w as Number, h as Number, arr as Array) as Void {
        dc.setColor(WIND, Graphics.COLOR_TRANSPARENT);
        var n = arr.size();

        var i = 1;
        while (i < n) {
            var px = x + (w*(i-1))/(n-1);
            var nx = x + (w*i)/(n-1);
            var py = y + (h*0.78) + ((i%4)*1);
            var ny = y + (h*0.78) + (((i+1)%4)*1);
            dc.drawLine(px, py, nx, ny);
            i += 1;
        }
    }

    function drawIcons(dc as Dc, x as Number, y as Number, w as Number, h as Number, arr as Array) as Void {
        var n = arr.size();
        var i = 0;
        while (i < n) {
            if ((i % 3) == 0) {
                var px = x + (w*i)/(n-1);
                var code = arr[i][:iconCode];
                drawIcon(dc, px, y + (h*0.30), code, 6);
            }
            i += 1;
        }
    }

    function mapT(row as Dictionary, minT as Number, maxT as Number, h as Number) as Number {
        var t = row[:tempC] == null ? minT : row[:tempC];
        var r = (t - minT)/(maxT - minT);
        return (r * (h*0.60)).toNumber() + (h*0.22);
    }
}
