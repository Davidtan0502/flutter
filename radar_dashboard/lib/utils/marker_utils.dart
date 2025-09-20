import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerUtils {
  static BitmapDescriptor getMarkerColor(String status) {
    switch (status.toLowerCase()) {
      case 'critical':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'high':
        return BitmapDescriptor.defaultMarkerWithHue(20.0); // Orange
      case 'medium':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'low':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  // Alternative if hue constants aren't available
  static BitmapDescriptor getMarkerColorByHueValue(String status) {
    const hueRed = 0.0;
    const hueOrange = 20.0;
    const hueYellow = 60.0;
    const hueGreen = 120.0;
    const hueCyan = 180.0;
    const hueAzure = 210.0;
    const hueBlue = 240.0;
    const hueViolet = 270.0;
    const hueMagenta = 300.0;
    const hueRose = 330.0;

    switch (status.toLowerCase()) {
      case 'critical':
        return BitmapDescriptor.defaultMarkerWithHue(hueRed);
      case 'high':
        return BitmapDescriptor.defaultMarkerWithHue(hueOrange);
      case 'medium':
        return BitmapDescriptor.defaultMarkerWithHue(hueBlue);
      case 'low':
        return BitmapDescriptor.defaultMarkerWithHue(hueGreen);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }
}