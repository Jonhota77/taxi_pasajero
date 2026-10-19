import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/geocoding_service.dart';
import '../services/nearby_drivers_service.dart';
import '../services/map_theme.dart';
import '../theme/app_theme.dart';
import 'trip_status_screen.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class HomeMapScreen extends StatefulWidget {
  final String category; // "taxi" o "intermunicipal"
  const HomeMapScreen({super.key, this.category = "taxi"});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _authService = AuthService();
  final _tripService = TripService();
  final _geocodingService = GeocodingService();
  final _nearbyDriversService = NearbyDriversService();
  final _mapController = MapController();
  final _destAddressController = TextEditingController();
  final _offerController = TextEditingController();

  Timer? _nearbyDriversTimer;
  List<Map<String, dynamic>> _nearbyDrivers = [];

  static const _defaultCenter = LatLng(0.8286, -77.6413); // Ipiales, Narino, por defecto

  LatLng? _currentPosition; // punto de recogida
  LatLng? _destination;
  String? _cityHint; // ciudad detectada por GPS, para busquedas de direccion mas precisas
  bool _adjustingPickup = false; // true = el proximo toque en el mapa ajusta la recogida
  bool _pickupSetManually = false;
  bool _requesting = false;
  bool _searchingAddress = false;
  String? _error;

  // Si el pasajero quiere pedir el viaje para mas tarde en vez de ahora.
  DateTime? _scheduledFor;

  bool get _isIntermunicipal => widget.category == "intermunicipal";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startNearbyDriversPolling();
    _checkForAppUpdate();
  }

  // Revisa si hay una version mas nueva de la app disponible y, si la
  // hay, le muestra al pasajero el dialogo para descargarla e instalarla.
  Future<void> _checkForAppUpdate() async {
    final info = await UpdateService().checkForUpdate();
    if (info != null && mounted) {
      showUpdateDialog(context, info);
    }
  }

  /// Consulta conductores conectados cerca cada 4 segundos y los dibuja
  /// como carros en el mapa, igual que en InDrive.
  void _startNearbyDriversPolling() {
    _fetchNearbyDrivers();
    _nearbyDriversTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchNearbyDrivers());
  }

  Future<void> _fetchNearbyDrivers() async {
    final token = await _authService.getToken();
    if (token == null) return;
    final center = _currentPosition ?? _defaultCenter;
    final drivers = await _nearbyDriversService.getNearbyDrivers(
      token: token,
      lat: center.latitude,
      lng: center.longitude,
      service: widget.category,
    );
    if (mounted) setState(() => _nearbyDrivers = drivers);
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!_pickupSetManually && mounted) {
        final here = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentPosition = here;
          _error = null;
        });
        _detectCityHint(here);
        // initialCenter del mapa solo se usa al construirlo: hay que mover
        // la camara cuando llega el GPS real.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_pickupSetManually) _mapController.move(here, 15);
        });
      }
    } catch (_) {
      if (!_pickupSetManually && mounted) {
        // Sin GPS no se adivina la ciudad: se deja el centro por defecto, se
        // avisa al pasajero y no se sesga la busqueda de direcciones a Ipiales.
        setState(() {
          _currentPosition = _defaultCenter;
          _error = "No pudimos detectar tu ubicacion. Activa el GPS y el permiso de ubicacion, o toca \"Ajustar mi ubicacion\" y marca tu punto de recogida en el mapa.";
        });
      }
    }
  }

  /// Detecta en que ciudad esta el pasajero, para que la busqueda de
  /// direcciones sepa exactamente donde buscar sin tenerlo escrito a mano.
  Future<void> _detectCityHint(LatLng point) async {
    final city = await _geocodingService.reverseGeocodeCity(point);
    if (mounted && city != null) {
      setState(() => _cityHint = city);
    }
  }

  void _handleMapTap(LatLng point) {
    final adjusting = _adjustingPickup;
    setState(() {
      if (adjusting) {
        _currentPosition = point;
        _pickupSetManually = true;
        _adjustingPickup = false;
        _error = null;
      } else {
        _destination = point;
        _error = null;
      }
    });
    // Si la recogida se marco a mano (otro pueblo), se actualiza la ciudad
    // de referencia para la busqueda de direcciones.
    if (adjusting) _detectCityHint(point);
  }

  /// Busca la direccion escrita y coloca el punto de destino solo, sin que
  /// el pasajero tenga que tocar el mapa (igual que en InDrive).
  Future<void> _searchDestinationAddress() async {
    final query = _destAddressController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchingAddress = true;
      _error = null;
    });

    final point = await _geocodingService.search(
      query,
      restrictToLocalArea: !_isIntermunicipal,
      cityHint: _isIntermunicipal ? null : _cityHint,
      near: _isIntermunicipal ? null : _currentPosition,
    );

    setState(() => _searchingAddress = false);

    if (point == null) {
      setState(() => _error = "No encontramos esa direccion. Intenta ser mas especifico, o toca el mapa directamente.");
      return;
    }

    setState(() => _destination = point);
    _mapController.move(point, 16);
  }

  void _startAdjustingPickup() {
    setState(() => _adjustingPickup = true);
  }

  void _resetSelection() {
    setState(() {
      _currentPosition = null;
      _destination = null;
      _adjustingPickup = false;
      _pickupSetManually = false;
      _destAddressController.clear();
    });
    _getCurrentLocation();
  }

  /// Abre el selector de fecha y hora para programar el viaje.
  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _clearSchedule() {
    setState(() => _scheduledFor = null);
  }

  String _formatScheduledDate(DateTime dt) {
    const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? "AM" : "PM";
    final minute = dt.minute.toString().padLeft(2, '0');
    return "${dt.day} ${months[dt.month - 1]} - $hour12:$minute $ampm";
  }

  Future<void> _requestTrip() async {
    if (_currentPosition == null) {
      setState(() => _error = "Ubicando tu posicion, espera un momento...");
      return;
    }

    // Si el pasajero escribio una direccion pero nunca toco la lupa ni
    // presiono Enter, la buscamos automaticamente ahora, para que no
    // tenga que acordarse de ese paso extra.
    if (_destination == null && _destAddressController.text.trim().isNotEmpty) {
      await _searchDestinationAddress();
      if (_destination == null) return;
    }

    if (_destination == null) {
      setState(() => _error = "Escribe tu destino y busca, o toca el mapa para elegirlo");
      return;
    }

    setState(() {
      _requesting = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      final offeredPrice = _offerController.text.isNotEmpty
          ? double.tryParse(_offerController.text.replaceAll(RegExp(r'[^\d]'), ''))
          : null;

      final trip = await _tripService.requestTrip(
        token: token!,
        originLat: _currentPosition!.latitude,
        originLng: _currentPosition!.longitude,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
        destAddress: _destAddressController.text,
        offeredPrice: offeredPrice,
        category: widget.category,
        scheduledFor: _scheduledFor,
      );

      if (!mounted) return;

      if (trip["status"] == "scheduled") {
        // El viaje quedo programado -- todavia no se le avisa a ningun
        // conductor, asi que no tiene sentido llevar al pasajero a la
        // pantalla de seguimiento en vivo. Se confirma y se vuelve.
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.schedule, color: AppTheme.navy),
                SizedBox(width: 10),
                Text("Viaje programado", style: TextStyle(color: AppTheme.textDark, fontSize: 16)),
              ],
            ),
            content: Text(
              "Tu viaje quedo programado para el ${_formatScheduledDate(_scheduledFor!)}. "
              "Te notificaremos cuando un conductor lo acepte.",
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Entendido", style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(); // vuelve al selector de servicio
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripStatusScreen(tripId: trip["id"])),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  void dispose() {
    _nearbyDriversTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentPosition ?? _defaultCenter;

    String instruction;
    if (_adjustingPickup) {
      instruction = "Toca el mapa para ajustar tu punto de recogida";
    } else if (_destination == null) {
      instruction = "Escribe tu destino abajo, o toca el mapa directamente";
    } else {
      instruction = "Recogida y destino listos";
    }

    return Scaffold(
      // Barra azul marino siempre visible, para los 2 tipos de viaje.
      appBar: AppBar(
        title: Text(_isIntermunicipal ? "Servicio especial" : "Taxi"),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _resetSelection,
            child: const Text("Reiniciar", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onTap: (tapPosition, point) => _handleMapTap(point),
            ),
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
              MarkerLayer(
                markers: [
                  ..._nearbyDrivers.map((d) {
                    final lat = (d["lat"] as num).toDouble();
                    final lng = (d["lng"] as num).toDouble();
                    final heading = (d["heading"] as num?)?.toDouble() ?? 0;
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 30,
                      height: 44,
                      child: Transform.rotate(
                        angle: heading * (3.1415926535 / 180),
                        child: Image.asset('assets/marcadores/carro_encendido.png', width: 20, height: 40),
                      ),
                    );
                  }),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle, color: AppTheme.navy, size: 36),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: AppTheme.danger, size: 40),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Text(
                instruction,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            top: 66,
            left: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: MapTheme.isDark,
              builder: (context, isDark, _) => Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20, color: AppTheme.textDark),
                  tooltip: isDark ? "Mapa claro" : "Mapa oscuro",
                  onPressed: MapTheme.toggle,
                ),
              ),
            ),
          ),
          if (!_isIntermunicipal)
            Positioned(
              top: 66,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _startAdjustingPickup,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text("Ajustar mi ubicacion", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _resetSelection,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text("Reiniciar puntos", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  TextField(
                    controller: _destAddressController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchDestinationAddress(),
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: InputDecoration(
                      labelText: _isIntermunicipal
                          ? "Destino (ej: Pasto, barrio, direccion)"
                          : "Direccion o barrio de destino",
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.place_outlined, color: AppTheme.textMuted),
                      suffixIcon: _searchingAddress
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: AppTheme.textMuted),
                              onPressed: _searchDestinationAddress,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Elegir entre pedir el viaje ahora, o programarlo.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickScheduledDateTime,
                          icon: Icon(Icons.schedule, size: 18, color: AppTheme.navy),
                          label: Text(
                            _scheduledFor == null ? "Programar para mas tarde" : _formatScheduledDate(_scheduledFor!),
                            style: TextStyle(fontSize: 14, fontWeight: _scheduledFor != null ? FontWeight.w700 : FontWeight.w500, color: AppTheme.navy),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _scheduledFor != null ? AppTheme.navy : const Color(0xFFB6BFCF), width: _scheduledFor != null ? 2 : 1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_scheduledFor != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppTheme.textDark),
                          tooltip: "Quitar programacion",
                          onPressed: _clearSchedule,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _offerController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: InputDecoration(
                      labelText: "Cuanto ofreces? (opcional)",
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.attach_money, color: AppTheme.textMuted),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 16),
                  // Boton de accion principal: amarillo con texto azul marino
                  // (estilo definido en AppTheme.light()).
                  ElevatedButton(
                    onPressed: _requesting ? null : _requestTrip,
                    child: _requesting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.navy))
                        : Text(
                            _scheduledFor != null
                                ? "Programar viaje"
                                : (_isIntermunicipal ? "Solicitar servicio especial" : "Pedir Taxi"),
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
}
