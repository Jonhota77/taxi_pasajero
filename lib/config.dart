/// Configuración de conexión al backend.
///
/// Apuntando al VPS de pruebas (Bipy), con HTTPS real.
/// Si en algún momento necesitas volver a probar contra tu propia
/// computadora (localhost), solo cambia _host de nuevo.
class AppConfig {
  static const String _host = "app.192.241.191.157.nip.io";
  static String get apiBaseUrl => "https://$_host";
  static String get wsBaseUrl => "wss://$_host";
}
