import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Convierte una direccion o nombre de lugar escrito por el usuario en
/// coordenadas (lat/lng), usando Nominatim (buscador gratuito de OpenStreetMap).
class GeocodingService {
  // Caja de respaldo (Ipiales): solo se usa si no se conoce la ubicacion del usuario.
  static const String _localViewbox = "-77.7613,0.9486,-77.5213,0.7086";
  static const String _wideViewbox = "-79.5,2.5,-75.5,-1.5";

  // Mitad del lado (en grados, ~27 km) de la zona local centrada en el usuario.
  static const double _localRadiusDeg = 0.25;
  // En busquedas urbanas se descartan resultados mas lejos que esto del usuario
  // (evita ubicar el destino en otra ciudad que tenga una calle con el mismo nombre).
  static const double _maxLocalDistanceKm = 60;

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
  Future<LatLng?> search(
    String query, {
    bool restrictToLocalArea = true,
    String? cityHint,
    LatLng? near, // referencia (ubicacion/recogida del usuario) para centrar la busqueda
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final hasCity = cityHint != null && cityHint.trim().isNotEmpty;
    final fullQuery = hasCity ? "$trimmed, $cityHint, Colombia" : trimmed;

    final point = await _tryFetch(fullQuery, restrictToLocalArea, near);
    if (point != null) return point;

    // Si con la ciudad agregada no encontro nada, reintenta con el texto
    // original solo (por si el nombre de la ciudad confundio la busqueda).
    if (hasCity) {
      final fallback = await _tryFetch(trimmed, restrictToLocalArea, near);
      if (fallback != null) return fallback;
    }

    // Ultimo respaldo: busqueda sin restriccion de zona, para no dejar al
    // pasajero sin resultado. Se descartan los resultados lejanos al usuario.
    if (restrictToLocalArea) {
      final wide = await _tryFetch(fullQuery, false, near);
      if (_isNear(wide, near)) return wide;

      if (hasCity) {
        final wideNoCity = await _tryFetch(trimmed, false, near);
        if (_isNear(wideNoCity, near)) return wideNoCity;
      }
    }

    return null;
  }

  /// Caja de busqueda "izquierda,arriba,derecha,abajo" centrada en [near].
  String _boxAround(LatLng near) {
    final west = near.longitude - _localRadiusDeg;
    final east = near.longitude + _localRadiusDeg;
    final north = near.latitude + _localRadiusDeg;
    final south = near.latitude - _localRadiusDeg;
    return "$west,$north,$east,$south";
  }

  bool _isNear(LatLng? point, LatLng? near) {
    if (point == null) return false;
    if (near == null) return true;
    return const Distance().as(LengthUnit.Kilometer, near, point) <= _maxLocalDistanceKm;
  }

  Future<LatLng?> _tryFetch(String query, bool restrictToLocalArea, LatLng? near) async {
    // Con ubicacion conocida la caja se centra en el usuario; si no, se usa la
    // de Ipiales (zona local) o la amplia (intermunicipal), como antes.
    final viewbox = near != null
        ? _boxAround(near)
        : (restrictToLocalArea ? _localViewbox : _wideViewbox);

    final uri = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=${Uri.encodeQueryComponent(query)}"
      "&format=json&limit=1&countrycodes=co"
      "&viewbox=$viewbox"
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
