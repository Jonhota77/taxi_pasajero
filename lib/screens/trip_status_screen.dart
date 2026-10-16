import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/rating_service.dart';
import '../widgets/rating_widget.dart';
import '../services/map_theme.dart';
import '../theme/app_theme.dart';

class TripStatusScreen extends StatefulWidget {
  final String tripId;
  const TripStatusScreen({super.key, required this.tripId});

  @override
  State<TripStatusScreen> createState() => _TripStatusScreenState();
}

class _TripStatusScreenState extends State<TripStatusScreen> {
  final _authService = AuthService();
  final _tripService = TripService();
  final _ratingService = RatingService();
  final _mapController = MapController();

  String _status = "requested";
  String _statusText = "Buscando un conductor cercano...";
  String? _driverName;
  String? _driverPhone;
  double? _price;
  double? _finalPrice;
  double? _proposedPrice;
  String? _nequiNumber;
  String? _daviplataNumber;
  bool _deciding = false;

  LatLng? _originPoint;
  LatLng? _destinationPoint;
  LatLng? _driverPosition;
  double _driverHeading = 0;
  Timer? _driverLocationTimer;

  // NUEVO: controla si el panel de abajo esta desplegado o solo la franja
  // pequena -- para dejarle todo el espacio posible al mapa.
  bool _panelExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
    _listenForUpdates();
  }

  Future<void> _loadTripDetails() async {
    final token = await _authService.getToken();
    if (token == null) return;
    try {
      final trip = await _tripService.getTripAuthenticated(token, widget.tripId);
      if (!mounted) return;
      setState(() {
        _status = trip["status"] ?? _status;
        final oLat = trip["origin_lat"];
        final oLng = trip["origin_lng"];
        final dLat = trip["destination_lat"];
        final dLng = trip["destination_lng"];
        if (oLat != null && oLng != null) {
          _originPoint = LatLng((oLat as num).toDouble(), (oLng as num).toDouble());
        }
        if (dLat != null && dLng != null) {
          _destinationPoint = LatLng((dLat as num).toDouble(), (dLng as num).toDouble());
        }
        _nequiNumber = trip["nequi_number"];
        _daviplataNumber = trip["daviplata_number"];
        _driverPhone = trip["driver_phone"];
      });
      if (_status == "accepted" || _status == "in_progress") {
        _startDriverLocationPolling();
      }
    } catch (_) {
      // Si falla, seguimos con lo que llegue por WebSocket
    }
  }

  void _startDriverLocationPolling() {
    _driverLocationTimer?.cancel();
    _fetchDriverLocation();
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchDriverLocation());
  }

  Future<void> _fetchDriverLocation() async {
    final token = await _authService.getToken();
    if (token == null) return;
    final loc = await _tripService.getDriverLocation(token, widget.tripId);
    if (loc != null && mounted) {
      setState(() {
        _driverPosition = LatLng((loc["lat"] as num).toDouble(), (loc["lng"] as num).toDouble());
        _driverHeading = (loc["heading"] as num?)?.toDouble() ?? 0;
      });
    }
  }

  Future<void> _listenForUpdates() async {
    final userId = await _authService.getUserId();
    final token = await _authService.getToken();
    if (userId == null || token == null) return;

    final channel = _tripService.connectLiveUpdates(userId, token);
    channel.stream.listen((raw) {
      final data = jsonDecode(raw);
      if (data["trip_id"] != widget.tripId) return;
      _handleEvent(data);
    });
  }

  void _handleEvent(Map<String, dynamic> data) {
    setState(() {
      switch (data["event"]) {
        case "trip_counter_offer":
          _status = "pending_confirmation";
          _driverName = data["driver_name"];
          _proposedPrice = (data["proposed_price"] as num?)?.toDouble();
          _statusText = "$_driverName propone un precio distinto";
          _panelExpanded = true; // hay que decidir, se muestra de una
          break;
        case "trip_accepted":
          _status = "accepted";
          _driverName = data["driver_name"];
          _price = (data["price"] as num?)?.toDouble();
          _nequiNumber = data["nequi_number"];
          _daviplataNumber = data["daviplata_number"];
          _statusText = "$_driverName acepto tu viaje y va en camino";
          _startDriverLocationPolling();
          break;
        case "trip_started":
          _status = "in_progress";
          _statusText = "Viaje en curso";
          _startDriverLocationPolling();
          break;
        case "trip_completed":
          _status = "completed";
          _finalPrice = (data["final_price"] as num).toDouble();
          _statusText = "Viaje completado";
          _driverLocationTimer?.cancel();
          _panelExpanded = true; // para ver el total y calificar
          break;
      }
    });
    if (data["event"] == "trip_accepted") {
      _loadTripDetails(); // trae el telefono del conductor
    }
  }

  /// Abre el marcador de llamadas del celular con el numero del conductor.
  Future<void> _callDriver() async {
    if (_driverPhone == null) return;
    final uri = Uri(scheme: 'tel', path: _driverPhone!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el marcador de llamadas")),
      );
    }
  }

  Future<void> _respondToOffer(bool accept) async {
    setState(() => _deciding = true);
    final token = await _authService.getToken();
    try {
      final trip = await _tripService.confirmPrice(token!, widget.tripId, accept);
      if (accept) {
        setState(() {
          _status = "accepted";
          _price = _proposedPrice;
          _nequiNumber = trip["nequi_number"];
          _daviplataNumber = trip["daviplata_number"];
          _driverPhone = trip["driver_phone"];
          _statusText = "Precio confirmado. El conductor va en camino.";
          _panelExpanded = false;
        });
        _startDriverLocationPolling();
      } else {
        setState(() {
          _status = "requested";
          _proposedPrice = null;
          _statusText = "Rechazaste esa propuesta. Buscando otro conductor...";
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    } finally {
      setState(() => _deciding = false);
    }
  }

  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    super.dispose();
  }

  bool get _hasMap => _originPoint != null && _destinationPoint != null;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // El panel se queda desplegado solo, sin depender del toque, cuando hay
    // que decidir algo (contraoferta) o cuando el viaje ya termino.
    final forceExpanded = _status == "pending_confirmation" || _status == "completed";
    final isExpanded = _panelExpanded || forceExpanded;

    return Scaffold(
      backgroundColor: AppTheme.navyDeep,
      body: Stack(
        children: [
          if (_hasMap) Positioned.fill(child: _buildMap()) else const Center(child: CircularProgressIndicator(color: AppTheme.yellow)),

          // Panel inferior: franja pequena por defecto, se despliega al tocarla.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              height: isExpanded ? screenHeight * 0.55 : 110,
              decoration: const BoxDecoration(
                color: AppTheme.navyDeep,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: forceExpanded ? null : () => setState(() => _panelExpanded = !_panelExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatusIcon(size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _statusText,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!forceExpanded) ...[
                                const SizedBox(width: 6),
                                Icon(isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white54, size: 20),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          children: [
                            if (_status == "pending_confirmation" && _proposedPrice != null) ...[
                              Text(
                                "Precio propuesto: \$${_proposedPrice!.toStringAsFixed(0)} COP",
                                style: const TextStyle(color: AppTheme.yellow, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _deciding ? null : () => _respondToOffer(false),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.dangerOnDark), minimumSize: const Size.fromHeight(44)),
                                      child: const Text("Rechazar", style: TextStyle(color: AppTheme.dangerOnDark)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _deciding ? null : () => _respondToOffer(true),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size.fromHeight(44)),
                                      child: _deciding
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text("Aceptar", style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_status != "pending_confirmation" && _price != null) ...[
                              Text(
                                "Precio acordado: \$${_price!.toStringAsFixed(0)} COP",
                                style: const TextStyle(color: AppTheme.yellow, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if ((_status == "accepted" || _status == "in_progress") && _driverPhone != null) ...[
                              ElevatedButton.icon(
                                onPressed: _callDriver,
                                icon: const Icon(Icons.call, color: Colors.white),
                                label: Text("Llamar a $_driverName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if ((_status == "accepted" || _status == "in_progress") && (_nequiNumber != null || _daviplataNumber != null))
                              _buildPaymentOptions(),
                            if (_finalPrice != null) ...[
                              Text(
                                "Total: \$${_finalPrice!.toStringAsFixed(0)} COP",
                                style: const TextStyle(color: AppTheme.yellow, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              RatingWidget(
                                onSubmit: (score, comment) async {
                                  final token = await _authService.getToken();
                                  await _ratingService.rateTrip(token!, widget.tripId, score, comment);
                                },
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.yellow, minimumSize: const Size.fromHeight(48)),
                                child: const Text("Volver al inicio", style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final origin = _originPoint!;
    final destination = _destinationPoint!;
    final points = [origin, destination, if (_driverPosition != null) _driverPosition!];

    final cameraFit = points.length > 1
        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(50))
        : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(50), maxZoom: 15);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCameraFit: cameraFit),
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: MapTheme.isDark,
              builder: (context, isDark, _) {
                final tileLayer = TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.jonhjota.taxi_pasajero',
                );
                if (!isDark) return tileLayer;
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileLayer,
                );
              },
            ),
            MarkerLayer(markers: [
              Marker(point: origin, width: 36, height: 36, child: const Icon(Icons.person_pin_circle, color: AppTheme.navy, size: 32)),
              Marker(point: destination, width: 36, height: 36, child: const Icon(Icons.location_on, color: AppTheme.danger, size: 34)),
              if (_driverPosition != null)
                Marker(
                  point: _driverPosition!,
                  width: 32,
                  height: 32,
                  child: Transform.rotate(
                    angle: _driverHeading * (3.1415926535 / 180),
                    child: Container(
                      decoration: const BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
                      child: const Icon(Icons.directions_car, color: AppTheme.yellow, size: 20),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: ValueListenableBuilder<bool>(
              valueListenable: MapTheme.isDark,
              builder: (context, isDark, _) => Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18, color: AppTheme.navyDeep),
                  tooltip: isDark ? "Mapa claro" : "Mapa oscuro",
                  onPressed: MapTheme.toggle,
                ),
              ),
            ),
          ),
        ),
        if (_driverPosition != null)
          Positioned(
            top: 16,
            left: 64,
            right: 16,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                  child: const Text("🚕 Conductor en vivo", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Formas de pago", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          if (_nequiNumber != null) _paymentRow("Nequi", _nequiNumber!, Colors.pinkAccent),
          if (_daviplataNumber != null) _paymentRow("Daviplata", _daviplataNumber!, AppTheme.dangerOnDark),
          _paymentRow("Efectivo", "Sin problema, paga directo al conductor", AppTheme.successOnDark),
        ],
      ),
    );
  }

  Widget _paymentRow(String method, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text("$method: ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusIcon({double size = 56}) {
    switch (_status) {
      case "pending_confirmation":
        return Icon(Icons.help_outline, color: AppTheme.yellow, size: size);
      case "accepted":
        return Icon(Icons.directions_car, color: AppTheme.yellow, size: size);
      case "in_progress":
        return Icon(Icons.navigation, color: AppTheme.successOnDark, size: size);
      case "completed":
        return Icon(Icons.check_circle, color: AppTheme.successOnDark, size: size);
      default:
        return SizedBox(width: size, height: size, child: const CircularProgressIndicator(color: AppTheme.yellow, strokeWidth: 2));
    }
  }
}
