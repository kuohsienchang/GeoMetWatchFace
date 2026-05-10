using Toybox.ActivityMonitor;

class HealthStore {

    function initialize() {}

    function getHeartRate() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info != null && info has :currentHeartRate) {
            return info[:currentHeartRate];
        }
        return null;
    }

    function getSpO2() as Number or Null {
        // Device availability varies by model/permissions.
        var info = ActivityMonitor.getInfo();
        if (info != null && info has :spo2) {
            return info[:spo2];
        }
        return null;
    }
}
