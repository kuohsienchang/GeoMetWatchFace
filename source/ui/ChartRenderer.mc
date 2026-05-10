using Toybox.Graphics;

class ChartRenderer {

    const GRID = 0x39E7;
    const TEMP = 0xF81F;
    const PREC = 0x07FF;
    const WIND = 0xF800;

    function initialize() {}

    function drawHourlyChart(dc as Dc, x as Number, y as Number, w as Number, h as Number, hourly as Array) as Void {
        dc.setColor(GRID, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);

        if (hourly == null || hourly.size() < 2) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + w/2, y + h/2, Graphics.FONT_XTINY, "No data", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        drawGrid(dc, x, y, w, h, 12, 4);
        drawPrecip(dc, x, y, w, h, hourly);
        drawTemp(dc, x, y, w, h, hourly);
        drawWind(dc, x, y, w, h, hourly);
        drawIcons(dc, x, y, w, h, hourly);
    }

    function drawDailyStrip(dc as Dc, x as Number, y as Number, w as Number, h as Number, daily as Array) as Void {
        dc.setColor(GRID, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);

        if (daily == null || daily.size() == 0) { return; }

        var n = daily.size();
        if (n > 5) { n = 5; }
        var cw = (w / n).toNumber();

        var i = 0;
        while (i < n) {
            var row = daily[i];
            var cx = x + i*cw + cw/2;
            var label = row has :dayLabel ? row[:dayLabel] : ("D+" + i);
            var mn = row[:minC] == null ? "--" : row[:minC].format("%.0f");
            var mx = row[:maxC] == null ? "--" : row[:maxC].format("%.0f");

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);

            drawIcon(dc, cx, y + h/2, row[:iconCode]);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + h - 14, Graphics.FONT_XTINY, mn + "°/" + mx + "°", Graphics.TEXT_JUSTIFY_CENTER);

            i += 1;
        }
    }

    function drawIcon(dc as Dc, x as Number, y as Number, code as String or Null) as Void {
        var c = Graphics.COLOR_WHITE;
        if (code == "sun") { c = Graphics.COLOR_YELLOW; }
        if (code == "rain") { c = Graphics.COLOR_CYAN; }
        if (code == "snow") { c = Graphics.COLOR_LT_GRAY; }
        if (code == "storm") { c = Graphics.COLOR_RED; }

        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
    }

    function drawGrid(dc as Dc, x as Number, y as Number, w as Number, h as Number, cols as Number, rows as Number) as Void {
        var i = 1;
        while (i < cols) {
            var gx = x + (w*i)/cols;
            dc.drawLine(gx, y, gx, y+h);
            i += 1;
        }
        var j = 1;
        while (j < rows) {
            var gy = y + (h*j)/rows;
            dc.drawLine(x, gy, x+w, gy);
            j += 1;
        }
    }

    function drawPrecip(dc as Dc, x as Number, y as Number, w as Number, h as Number, arr as Array) as Void {
        var n = arr.size();
        dc.setColor(PREC, Graphics.COLOR_TRANSPARENT);

        var maxp = 0.1;
        var i = 0;
        while (i < n) {
            var p = arr[i][:precipMm] == null ? 0.0 : arr[i][:precipMm];
            if (p > maxp) { maxp = p; }
            i += 1;
        }

        var bw = (w / n).toNumber();
        i = 0;
        while (i < n) {
            var pp = arr[i][:precipMm] == null ? 0.0 : arr[i][:precipMm];
            var bh = ((pp / maxp) * (h * 0.35)).toNumber();
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
        if (maxT <= minT) { maxT = minT + 1; }

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
            var py = y + (h*0.72) + ((i%3)*2);
            var ny = y + (h*0.72) + (((i+1)%3)*2);
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
                drawIcon(dc, px, y + (h*0.38), arr[i][:iconCode]);
            }
            i += 1;
        }
    }

    function mapT(row as Dictionary, minT as Number, maxT as Number, h as Number) as Number {
        var t = row[:tempC] == null ? minT : row[:tempC];
        var r = (t - minT) / (maxT - minT);
        return (r * (h * 0.62)).toNumber() + (h * 0.20);
    }
}
