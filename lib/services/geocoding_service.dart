import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Convierte una direccion o nombre de lugar escrito por el usuario en
/// coordenadas (lat/lng), usando Nominatim (buscador gratuito de OpenStreetMap).
class GeocodingService {
  static const String _localViewbox = "-77.7613,0.9486,-77.5213,0.7086";
  static const String _wideViewbox = "-79.5,2.5,-75.5,-1.5";

  static const Map<String, String> _headers = {
    "User-Agent": "TransportesOJ7App/1.0 (contacto@transportesoj7.com)",
  };

  /// NUEVO: detecta en que ciudad esta el punto dado (usando el GPS real
  /// del celular), para que la busqueda de direcciones sea inteligente --
  /// si el GPS dice que el pasajero esta en Ipiales, busca en Ipiales; si
  /// dice que esta en Pasto, busca en Pasto. Asi no queda fijo a una sola
  /// ciudad para siempre.
  Future<String?> reverseGeocodeCity(LatLng point) async {
    final uri = Uri.parse(
      "https://nominatim.openstreetmap.org/reverse"
      "?lat=${point.latitude}&lon=${point.longitude}"
      "&format=json&addressdetails=1&zoom=10",
    );
    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final address = data["address"];
      if (address == null) return null;
      return address["city"] ?? address["town"] ?? address["municipality"] ?? address["county"];
    } catch (_) {
      return null;
    }
  }

  /// Busca una direccion. Si se le pasa "cityHint" (la ciudad detectada por
  /// GPS), se agrega a la busqueda para encontrar la direccion exacta con
  /// mucha mas precision -- muchas direcciones con numero de casa solo se
  /// encuentran si se busca junto con el nombre de la ciudad.
  Future<LatLng?> search(String query, {bool restrictToLocalArea = true, String? cityHint}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final fullQuery = (cityHint != null && cityHint.trim().isNotEmpty)
        ? "$trimmed, $cityHint, Colombia"
        : trimmed;

    final point = await _tryFetch(fullQuery, restrictToLocalArea);
    if (point != null) return point;

    // Si con la ciudad agregada no encontro nada, reintenta con el texto
    // original solo (por si el nombre de la ciudad confundio la busqueda).
    if (cityHint != null && cityHint.trim().isNotEmpty) {
      final fallback = await _tryFetch(trimmed, restrictToLocalArea);
      if (fallback != null) return fallback;
    }

    // Ultimo respaldo: busqueda amplia sin restriccion de zona, para no
    // dejar al pasajero sin resultado.
    if (restrictToLocalArea) {
      return _tryFetch(fullQuery, false);
    }

    return null;
  }

  Future<LatLng?> _tryFetch(String query, bool restrictToLocalArea) async {
    final uri = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeQueryComponent(query)}"
      "&format=json&limit=1&countrycodes=co"
      "&viewbox=${restrictToLocalArea ? _localViewbox : _wideViewbox}"
      "&bounded=${restrictToLocalArea ? 1 : 0}",
    );

    try {
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;

      final lat = double.tryParse(data[0]["lat"].toString());
      final lon = double.tryParse(data[0]["lon"].toString());
      if (lat == null || lon == null) return null;

      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
