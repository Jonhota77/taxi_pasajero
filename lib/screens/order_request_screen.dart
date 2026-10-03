import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';
import 'order_status_screen.dart';

class OrderRequestScreen extends StatefulWidget {
  final String serviceType; // "piaggio" o "delivery"
  const OrderRequestScreen({super.key, required this.serviceType});

  @override
  State<OrderRequestScreen> createState() => _OrderRequestScreenState();
}

class _OrderRequestScreenState extends State<OrderRequestScreen> {
  final _authService = AuthService();
  final _orderService = OrderService();
  final _geocodingService = GeocodingService();
  final _mapController = MapController();

  final _itemController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _destAddressController = TextEditingController();
  final _offerController = TextEditingController();

  static const _defaultCenter = LatLng(0.8286, -77.6413);

  LatLng? _pickup;
  LatLng? _destination;
  String? _cityHint; // ciudad detectada por GPS, para busquedas de direccion mas precisas
  bool _adjustingPickup = false; // true = el proximo toque en el mapa ajusta la recogida
  bool _pickupSetManually = false;
  bool _requesting = false;
  bool _searchingPickup = false;
  bool _searchingDestination = false;
  String? _error;

  bool get _isPiaggio => widget.serviceType == "piaggio";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!_pickupSetManually && mounted) {
        setState(() => _pickup = LatLng(pos.latitude, pos.longitude));
        _detectCityHint(LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {
      if (!_pickupSetManually && mounted) {
        setState(() => _pickup = _defaultCenter);
        _detectCityHint(_defaultCenter);
      }
    }
  }

  /// Detecta en que ciudad esta el cliente, para que la busqueda de
  /// direcciones de origen y destino sea mas precisa.
  Future<void> _detectCityHint(LatLng point) async {
    final city = await _geocodingService.reverseGeocodeCity(point);
    if (mounted && city != null) {
      setState(() => _cityHint = city);
    }
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      if (_adjustingPickup) {
        _pickup = point;
        _pickupSetManually = true;
        _adjustingPickup = false;
      } else {
        _destination = point;
        _error = null;
      }
    });
  }

  void _startAdjustingPickup() {
    setState(() => _adjustingPickup = true);
  }

  /// Busca la direccion de origen escrita y coloca el punto solo, sin
  /// necesidad de tocar el mapa.
  Future<void> _searchPickupAddress() async {
    final query = _pickupAddressController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchingPickup = true;
      _error = null;
    });

    // Piaggio/domicilios son siempre servicios locales, asi que la busqueda
    // queda encerrada en Ipiales y alrededores, mas la ciudad detectada por GPS.
    final point = await _geocodingService.search(query, restrictToLocalArea: true, cityHint: _cityHint);

    setState(() => _searchingPickup = false);

    if (point == null) {
      setState(() => _error = "No encontramos esa direccion de origen. Intenta ser mas especifico, o toca el mapa.");
      return;
    }

    setState(() {
      _pickup = point;
      _pickupSetManually = true;
    });
    _mapController.move(point, 16);
  }

  /// Busca la direccion de destino escrita y coloca el punto solo.
  Future<void> _searchDestinationAddress() async {
    final query = _destAddressController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchingDestination = true;
      _error = null;
    });

    final point = await _geocodingService.search(query, restrictToLocalArea: true, cityHint: _cityHint);

    setState(() => _searchingDestination = false);

    if (point == null) {
      setState(() => _error = "No encontramos esa direccion de destino. Intenta ser mas especifico, o toca el mapa.");
      return;
    }

    setState(() => _destination = point);
    _mapController.move(point, 16);
  }

  void _resetSelection() {
    setState(() {
      _pickup = null;
      _destination = null;
      _adjustingPickup = false;
      _pickupSetManually = false;
      _pickupAddressController.clear();
      _destAddressController.clear();
    });
    _getCurrentLocation();
  }

  Future<void> _submit() async {
    // Si escribieron una direccion pero no la buscaron a proposito
    // (no tocaron la lupa ni presionaron Enter), la buscamos ahora.
    if (_destination == null && _destAddressController.text.trim().isNotEmpty) {
      await _searchDestinationAddress();
      if (_destination == null) return;
    }
    if (_pickup == null && _pickupAddressController.text.trim().isNotEmpty) {
      await _searchPickupAddress();
      if (_pickup == null) return;
    }

    if (_pickup == null || _destination == null) {
      setState(() => _error = "Escribe el origen y destino, o toca el mapa para elegirlos");
      return;
    }
    if (_itemController.text.trim().isEmpty) {
      setState(() => _error = _isPiaggio
          ? "Describe qué necesitas transportar"
          : "Describe qué necesitas que te traigan");
      return;
    }

    setState(() {
      _requesting = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      final offeredPrice = _offerController.text.trim().isEmpty
          ? null
          : double.tryParse(_offerController.text.trim().replaceAll(RegExp(r'[^\d]'), ''));

      final order = await _orderService.requestOrder(
        token: token!,
        serviceType: widget.serviceType,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        destLat: _destination!.latitude,
        destLng: _destination!.longitude,
        pickupAddress: _pickupAddressController.text,
        destAddress: _destAddressController.text,
        itemDescription: _itemController.text.trim(),
        recipientName: _recipientNameController.text.trim().isEmpty ? null : _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim().isEmpty ? null : _recipientPhoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        offeredPrice: offeredPrice,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: order["id"])),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickup ?? _defaultCenter;
    final title = _isPiaggio ? "Solicitar transporte de carga" : "Solicitar domicilio";

    String instruction;
    if (_adjustingPickup) {
      instruction = "Toca el mapa para ajustar tu punto de recogida";
    } else {
      instruction = "Escribe las direcciones abajo, o toca el mapa directamente";
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _resetSelection,
            child: const Text("Reiniciar", style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15,
                    onTap: (tapPosition, point) => _handleMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jonhjota.taxi_pasajero',
                    ),
                    MarkerLayer(markers: [
                      if (_pickup != null)
                        Marker(point: _pickup!, width: 38, height: 38, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 32)),
                      if (_destination != null)
                        Marker(point: _destination!, width: 38, height: 38, child: const Icon(Icons.location_on, color: Colors.red, size: 36)),
                    ]),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _startAdjustingPickup,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text("Ajustar mi ubicacion", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _pickupAddressController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPickupAddress(),
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: InputDecoration(
                      labelText: "Direccion de origen",
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                      prefixIcon: const Icon(Icons.trip_origin, color: AppTheme.textMuted),
                      suffixIcon: _searchingPickup
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: AppTheme.textMuted),
                              onPressed: _searchPickupAddress,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _destAddressController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchDestinationAddress(),
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: InputDecoration(
                      labelText: "Direccion de destino",
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                      prefixIcon: const Icon(Icons.place_outlined, color: AppTheme.textMuted),
                      suffixIcon: _searchingDestination
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
                  _field(
                    _itemController,
                    _isPiaggio ? "¿Qué necesitas transportar? (ej: nevera y colchón)" : "¿Qué necesitas que te traigan? (ej: pollo asado x2)",
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _field(_offerController, "¿Cuánto ofreces? (opcional)", type: TextInputType.number),
                  const SizedBox(height: 10),
                  _field(_recipientNameController, "Nombre de quien recibe (opcional)"),
                  const SizedBox(height: 10),
                  _field(_recipientPhoneController, "Teléfono de quien recibe (opcional)", type: TextInputType.phone),
                  const SizedBox(height: 10),
                  _field(_notesController, "Notas adicionales (opcional)", maxLines: 2),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requesting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.actionGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _requesting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Solicitar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
      ),
    );
  }
}
