import 'package:flutter/foundation.dart';

/// Controla si los mapas de la app se ven en modo claro u oscuro.
///
/// IMPORTANTE: ya no usamos un proveedor de mapas externo (CartoDB) para el
/// modo oscuro, porque empezo a pedir una clave de pago. En su lugar,
/// invertimos los colores del mismo mapa que ya usamos (OpenStreetMap),
/// el mismo truco que usan muchas apps para simular un mapa oscuro sin
/// depender de ningun servidor adicional.
class MapTheme {
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(false);

  static void toggle() {
    isDark.value = !isDark.value;
  }
}
