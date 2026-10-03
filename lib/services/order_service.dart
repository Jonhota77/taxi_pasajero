import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class OrderService {
  Future<Map<String, dynamic>> requestOrder({
    required String token,
    required String serviceType,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    String? pickupAddress,
    String? destAddress,
    required String itemDescription,
    String? recipientName,
    String? recipientPhone,
    String? notes,
    double? offeredPrice,
  }) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/orders"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "service_type": serviceType,
        "pickup_lat": pickupLat,
        "pickup_lng": pickupLng,
        "destination_lat": destLat,
        "destination_lng": destLng,
        "pickup_address": pickupAddress,
        "destination_address": destAddress,
        "item_description": itemDescription,
        "recipient_name": recipientName,
        "recipient_phone": recipientPhone,
        "notes": notes,
        "requested_price": offeredPrice,
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo solicitar el pedido");
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getOrder(String token, String orderId) async {
    final res = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/orders/$orderId"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) {
      throw Exception("No se pudo consultar el pedido");
    }
    return jsonDecode(res.body);
  }

  Future<void> cancelOrder(String token, String orderId) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/orders/$orderId/cancel"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo cancelar el pedido");
    }
  }

  /// NUEVO: el cliente acepta o rechaza el precio que propuso el conductor.
  Future<Map<String, dynamic>> confirmPrice(String token, String orderId, bool accept) async {
    final uri = Uri.parse("${AppConfig.apiBaseUrl}/orders/$orderId/confirm-price")
        .replace(queryParameters: {"accept": accept.toString()});
    final res = await http.post(uri, headers: {"Authorization": "Bearer $token"});
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "No se pudo confirmar el precio");
    }
    return jsonDecode(res.body);
  }
}
