import 'dart:math';

class CoordTransform {
  static const double _pi = pi;
  static const double _xPi = pi * 3000.0 / 180.0;
  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  static List<double> bd09ToGcj02(double latitude, double longitude) {
    final x = longitude - 0.0065;
    final y = latitude - 0.006;
    final z = sqrt(x * x + y * y) - 0.00002 * sin(y * _xPi);
    final theta = atan2(y, x) - 0.000003 * cos(x * _xPi);
    final gcjLongitude = z * cos(theta);
    final gcjLatitude = z * sin(theta);
    return [gcjLatitude, gcjLongitude];
  }

  static List<double> wgs84ToGcj02(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) {
      return [latitude, longitude];
    }

    var dLat = _transformLat(longitude - 105.0, latitude - 35.0);
    var dLon = _transformLon(longitude - 105.0, latitude - 35.0);
    final radLat = latitude / 180.0 * _pi;
    var magic = sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * _pi);
    dLon = (dLon * 180.0) / (_a / sqrtMagic * cos(radLat) * _pi);
    final mgLat = latitude + dLat;
    final mgLon = longitude + dLon;
    return [mgLat, mgLon];
  }

  static bool _outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) {
      return true;
    }
    if (lat < 0.8293 || lat > 55.8271) {
      return true;
    }
    return false;
  }

  static double _transformLat(double x, double y) {
    var ret =
        -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * _pi) + 20.0 * sin(2.0 * x * _pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * _pi) + 40.0 * sin(y / 3.0 * _pi)) * 2.0 / 3.0;
    ret +=
        (160.0 * sin(y / 12.0 * _pi) + 320 * sin(y * _pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    var ret =
        300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * _pi) + 20.0 * sin(2.0 * x * _pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * _pi) + 40.0 * sin(x / 3.0 * _pi)) * 2.0 / 3.0;
    ret +=
        (150.0 * sin(x / 12.0 * _pi) + 300.0 * sin(x / 30.0 * _pi)) * 2.0 / 3.0;
    return ret;
  }
}
