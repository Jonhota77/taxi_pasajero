import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import 'home_map_screen.dart';
import 'order_request_screen.dart';

class ServiceSelectorScreen extends StatefulWidget {
  const ServiceSelectorScreen({super.key});

  @override
  State<ServiceSelectorScreen> createState() => _ServiceSelectorScreenState();
}

class _ServiceSelectorScreenState extends State<ServiceSelectorScreen> {
  final _authService = AuthService();
  final _tripService = TripService();
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _checkLocationEnabled();
    _connectForBroadcasts();
  }

  /// NUEVO: le recuerda al pasajero activar el GPS del celular apenas abre
  /// la app, para que no se encuentre con errores raros mas adelante al
  /// intentar pedir un viaje sin ubicacion.
  Future<void> _checkLocationEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Activa tu ubicacion", style: TextStyle(color: AppTheme.textDark)),
          content: const Text(
            "Para poder pedir un viaje, necesitamos que actives el GPS de tu celular.",
            style: TextStyle(color: AppTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Ahora no", style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text("Activar"),
            ),
          ],
        ),
      );
    }
  }

  /// NUEVO: mantiene una conexion abierta desde la pantalla principal (no
  /// solo durante un viaje activo), para poder recibir mensajes de la
  /// secretaria en cualquier momento -- promociones, ganadores de bonos,
  /// avisos generales.
  Future<void> _connectForBroadcasts() async {
    final userId = await _authService.getUserId();
    final token = await _authService.getToken();
    if (userId == null || token == null) return;

    _channel = _tripService.connectLiveUpdates(userId, token);
    _channel!.stream.listen((raw) {
      final data = jsonDecode(raw);
      if (data["event"] == "passenger_broadcast") {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        _showBroadcastDialog(data["message"] ?? "");
      }
    });
  }

  void _showBroadcastDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.campaign, color: AppTheme.navy),
            SizedBox(width: 10),
            Text("Bipy", style: TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Entendido", style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          children: [
            // Cabecera azul marino, consistente con el login.
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Image.asset("assets/images/logo_bipy.png", height: 34),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("¿Qué necesitas hoy?",
                        style: TextStyle(color: AppTheme.textDark, fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _ServiceCard(
                      icon: Icons.local_taxi,
                      title: "Taxi",
                      subtitle: "Viaje de pasajero, origen a destino",
                      featured: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeMapScreen(category: "taxi")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.airport_shuttle,
                      title: "Servicio especial",
                      subtitle: "Servicio público, buses, camionetas, vans, a nivel nacional",
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeMapScreen(category: "intermunicipal")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.local_shipping,
                      title: "Transporte de carga",
                      subtitle: "Piaggios, buses, camiones, turbo",
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrderRequestScreen(serviceType: "piaggio")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.delivery_dining,
                      title: "Domicilios",
                      subtitle: null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrderRequestScreen(serviceType: "delivery")),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de servicio. La del servicio principal ([featured]) va en azul
/// marino con el icono amarillo; las demas, en blanco con borde fino.
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool featured;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = featured ? Colors.white : AppTheme.textDark;
    final subtitleColor = featured ? const Color(0xFFC9D4E8) : AppTheme.textMuted;
    final tileColor = featured ? AppTheme.yellow : AppTheme.navy.withValues(alpha: 0.08);

    return Material(
      color: featured ? AppTheme.navy : AppTheme.cardBackground,
      elevation: featured ? 3 : 0,
      shadowColor: AppTheme.navy.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: featured ? AppTheme.navy : AppTheme.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: tileColor, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: AppTheme.navy, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: TextStyle(color: titleColor, fontSize: 19, fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: TextStyle(color: subtitleColor, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: featured ? AppTheme.yellow : AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
