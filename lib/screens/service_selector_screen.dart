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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionGreen),
              child: const Text("Activar", style: TextStyle(color: Colors.white)),
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
            Icon(Icons.campaign, color: AppTheme.primaryOrange),
            SizedBox(width: 10),
            Text("Bipy", style: TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Entendido", style: TextStyle(color: AppTheme.actionGreen, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior naranja, para que se vea consistente con el login.
            Container(
              width: double.infinity,
              color: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset("assets/images/logo_bipy.png", height: 32),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("¿Qué necesitas hoy?",
                        style: TextStyle(color: AppTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _ServiceCard(
                      icon: Icons.local_taxi,
                      title: "Taxi",
                      subtitle: "Viaje de pasajero, origen a destino",
                      color: AppTheme.primaryOrange,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeMapScreen(category: "taxi")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.airport_shuttle,
                      title: "Servicio especial",
                      subtitle: "Servicio público, buses, camionetas, vans, a nivel nacional",
                      color: Colors.deepPurple,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeMapScreen(category: "intermunicipal")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.local_shipping,
                      title: "Transporte de carga",
                      subtitle: "Piaggios, buses, camiones, turbo",
                      color: Colors.blueAccent,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrderRequestScreen(serviceType: "piaggio")),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ServiceCard(
                      icon: Icons.delivery_dining,
                      title: "Domicilios",
                      subtitle: null,
                      color: AppTheme.actionGreen,
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

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 26)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
