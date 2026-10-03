import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';

  Future<String?> register({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": phone,
        "password": password,
        "full_name": fullName,
        "role": "passenger",
      }),
    );

    if (res.statusCode == 200) return null; // Ã©xito, sin error
    final body = jsonDecode(res.body);
    return body["detail"]?.toString() ?? "Error al registrarse";
  }

  Future<String?> login({required String phone, required String password}) async {
    final res = await http.post(
      Uri.parse("${AppConfig.apiBaseUrl}/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "password": password, "role": "passenger"}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      return body["detail"]?.toString() ?? "TelÃ©fono o contraseÃ±a incorrectos";
    }

    final data = jsonDecode(res.body);
    final token = data["access_token"] as String;

    // Guardamos el token y luego pedimos los datos del usuario
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    final meRes = await http.get(
      Uri.parse("${AppConfig.apiBaseUrl}/auth/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (meRes.statusCode == 200) {
      final me = jsonDecode(meRes.body);
      await prefs.setString(_userIdKey, me["id"]);
      await prefs.setString(_userNameKey, me["full_name"]);
    }

    return null; // Ã©xito
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// NUEVO: confirma con el servidor si el token guardado todavÃ­a es
  /// valido. Se usa cuando la app vuelve de segundo plano (o al abrirla)
  /// para detectar una sesion vencida ANTES de que el usuario intente
  /// pedir un servicio y le salga un error a medias.
  ///
  /// Importante: si la peticion falla por un problema de red (sin
  /// internet, servidor caido momentaneamente), NO se considera que el
  /// token es invalido -- solo cerramos sesion cuando el servidor
  /// responde explicitamente que la credencial no es valida (401).
  /// Asi evitamos cerrarle la sesion a alguien solo porque se quedo
  /// sin seÃ±al un momento.
  Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await http.get(
        Uri.parse("${AppConfig.apiBaseUrl}/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      return res.statusCode == 200;
    } catch (e) {
      // Error de red/timeout: no cerramos sesion, asumimos que sigue
      // valido y ya se revalidarÃ¡ en el proximo intento.
      return true;
    }
  }
}
