import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Servicio separado a proposito, para no tener que editar trip_service.dart
/// (que ya tienes funcionando) y evitar cualquier riesgo de daño.
class RatingService {
  Future<void> rateTrip(String token, String tripId, int score, String? comment) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/trips/$tripId/rate"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"score": score, "comment": comment}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo enviar la calificacion");
    }
  }

  Future<bool> hasRated(String token, String tripId) async {
    final res = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/trips/$tripId/rating"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) return false;
    final data = jsonDecode(res.body);
    return data["rated"] == true;
  }
}
