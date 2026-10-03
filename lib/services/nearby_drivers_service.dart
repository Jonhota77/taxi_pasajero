import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class NearbyDriversService {
  Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required String token,
    required double lat,
    required double lng,
    String service = "taxi",
    double radiusKm = 6,
  }) async {
    final uri = Uri.parse("${AppConfig.apiBaseUrl}/drivers/nearby").replace(
      queryParameters: {
        "lat": lat.toString(),
        "lng": lng.toString(),
        "service": service,
        "radius_km": radiusKm.toString(),
      },
    );

    try {
      final res = await http.get(uri, headers: {"Authorization": "Bearer $token"});
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
