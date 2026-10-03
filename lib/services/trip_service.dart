import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class TripService {
  Future<Map<String, dynamic>> requestTrip({
    required String token,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originAddress,
    String? destAddress,
    double? offeredPrice,
    String category = "taxi",
    // NUEVO: si se manda, el viaje queda programado para esa fecha/hora en
    // vez de avisarle a los conductores de inmediato.
    DateTime? scheduledFor,
  }) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/trips"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "origin_lat": originLat,
        "origin_lng": originLng,
        "destination_lat": destLat,
        "destination_lng": destLng,
        "origin_address": originAddress,
        "destination_address": destAddress,
        "requested_price": offeredPrice,
        "category": category,
        "scheduled_for": scheduledFor?.toUtc().toIso8601String(),
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo solicitar el viaje");
    }
    return jsonDecode(res.body);
  }

  /// NUEVO: lista los viajes programados que aun no han salido, para
  /// poder revisarlos o cancelarlos antes de que llegue la hora.
  Future<List<dynamic>> getMyScheduledTrips(String token) async {
    final res = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/trips/scheduled/mine"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body);
  }

  /// CORREGIDO: antes no mandaba el token, y el backend ya exige autenticación
  /// para consultar un viaje. Ahora se llama "getTripAuthenticated" para dejar
  /// claro que requiere el token.
  Future<Map<String, dynamic>> getTripAuthenticated(String token, String tripId) async {
    final res = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/trips/$tripId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) {
      throw Exception("No se pudo consultar el viaje");
    }
    return jsonDecode(res.body);
  }

  /// NUEVO: ubicacion en vivo del conductor ya asignado al viaje, para
  /// mostrarlo moviendose en el mapa mientras se acerca (como InDrive).
  /// Devuelve null si el conductor aun no tiene posicion disponible.
  Future<Map<String, dynamic>?> getDriverLocation(String token, String tripId) async {
    final res = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/trips/$tripId/driver-location"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body);
  }

  /// NUEVO: el pasajero acepta o rechaza el precio que propuso el conductor.
  Future<Map<String, dynamic>> confirmPrice(String token, String tripId, bool accept) async {
    final uri = Uri.parse("${AppConfig.apiBaseUrl}/trips/$tripId/confirm-price")
        .replace(queryParameters: {"accept": accept.toString()});
    final res = await http.post(uri, headers: {"Authorization": "Bearer $token"});
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo confirmar el precio");
    }
    return jsonDecode(res.body);
  }

  WebSocketChannel connectLiveUpdates(String passengerId, String token) {
    final uri = Uri.parse("${AppConfig.wsBaseUrl}/ws/passenger/$passengerId?token=$token");
    return WebSocketChannel.connect(uri);
  }
}
