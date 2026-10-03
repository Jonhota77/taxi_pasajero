import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final _authService = AuthService();
  final _orderService = OrderService();

  String _status = "requested";
  String _statusText = "Buscando un conductor disponible...";
  String? _driverName;
  String? _driverPhone;
  double? _price;
  double? _proposedPrice; // contraoferta del conductor, pendiente de tu decision
  String? _nequiNumber;
  String? _daviplataNumber;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final userId = await _authService.getUserId();
    final token = await _authService.getToken();
    if (userId == null || token == null) return;

    final uri = Uri.parse("${AppConfig.wsBaseUrl}/ws/passenger/$userId?token=$token");
    final channel = WebSocketChannel.connect(uri);
    channel.stream.listen((raw) {
      final data = jsonDecode(raw);
      if (data["order_id"] != widget.orderId) return;
      _handleEvent(data);
    });
  }

  void _handleEvent(Map<String, dynamic> data) {
    setState(() {
      switch (data["event"]) {
        case "order_counter_offer":
          // El conductor propuso un precio distinto -- TU decides, no se acordo nada aun.
          _status = "pending_confirmation";
          _driverName = data["driver_name"];
          _proposedPrice = (data["proposed_price"] as num?)?.toDouble();
          _statusText = "$_driverName propone un precio distinto";
          break;
        case "order_accepted":
          _status = "accepted";
          _driverName = data["driver_name"];
          _price = (data["price"] as num?)?.toDouble();
          _nequiNumber = data["nequi_number"];
          _daviplataNumber = data["daviplata_number"];
          _statusText = "$_driverName acepto tu pedido";
          break;
        case "order_picked_up":
          _status = "picked_up";
          _statusText = "El conductor ya recogio tu pedido";
          break;
        case "order_completed":
          _status = "completed";
          _price = (data["price"] as num?)?.toDouble() ?? _price;
          _statusText = "Pedido entregado";
          break;
      }
    });
    // El evento order_accepted no manda el telefono del conductor, asi que
    // lo recargamos del servidor justo despues.
    if (data["event"] == "order_accepted") {
      _refreshOrder();
    }
  }

  /// NUEVO: consulta el pedido directo por HTTP (sin depender de un metodo
  /// nuevo en order_service.dart) para obtener el telefono del conductor
  /// justo despues de que acepta.
  Future<void> _refreshOrder() async {
    final token = await _authService.getToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse("${AppConfig.apiBaseUrl}/orders/${widget.orderId}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200 && mounted) {
        final order = jsonDecode(res.body);
        setState(() => _driverPhone = order["driver_phone"]);
      }
    } catch (_) {}
  }

  /// NUEVO: abre el marcador de llamadas del celular con el numero del
  /// conductor, para poder coordinar la entrega/recogida.
  Future<void> _callDriver() async {
    if (_driverPhone == null) return;
    final uri = Uri(scheme: 'tel', path: _driverPhone);
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
      final order = await _orderService.confirmPrice(token!, widget.orderId, accept);
      if (accept) {
        setState(() {
          _status = "accepted";
          _price = _proposedPrice;
          _nequiNumber = order["nequi_number"];
          _daviplataNumber = order["daviplata_number"];
          _driverPhone = order["driver_phone"];
          _statusText = "Precio confirmado. $_driverName va en camino.";
        });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIcon(),
              const SizedBox(height: 24),
              Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),

              // Contraoferta pendiente: el pasajero debe decidir
              if (_status == "pending_confirmation" && _proposedPrice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(
                        "Precio propuesto: \$${_proposedPrice!.toStringAsFixed(0)} COP",
                        style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _deciding ? null : () => _respondToOffer(false),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                              child: const Text("Rechazar", style: TextStyle(color: Colors.redAccent)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _deciding ? null : () => _respondToOffer(true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: _deciding
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text("Aceptar", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (_status != "pending_confirmation" && _price != null) ...[
                const SizedBox(height: 12),
                Text(
                  "Precio acordado: \$${_price!.toStringAsFixed(0)} COP",
                  style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
              // NUEVO: boton de llamada, visible mientras el pedido esta
              // aceptado o recogido y ya sabemos el telefono del conductor.
              if ((_status == "accepted" || _status == "picked_up") && _driverPhone != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _callDriver,
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: Text("Llamar a $_driverName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              if ((_status == "accepted" || _status == "picked_up") && (_nequiNumber != null || _daviplataNumber != null)) ...[
                const SizedBox(height: 20),
                _buildPaymentOptions(),
              ],
              if (_status == "completed") ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text("Volver al inicio", style: TextStyle(color: Colors.black)),
                ),
              ],
            ],
          ),
        ),
      ),
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
          if (_daviplataNumber != null) _paymentRow("Daviplata", _daviplataNumber!, Colors.redAccent),
          _paymentRow("Efectivo", "Sin problema, paga directo al conductor", Colors.greenAccent),
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

  Widget _buildIcon() {
    switch (_status) {
      case "pending_confirmation":
        return const Icon(Icons.help_outline, color: Colors.amber, size: 72);
      case "accepted":
        return const Icon(Icons.local_shipping, color: Colors.amber, size: 72);
      case "picked_up":
        return const Icon(Icons.navigation, color: Colors.greenAccent, size: 72);
      case "completed":
        return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72);
      default:
        return const CircularProgressIndicator(color: Colors.amber);
    }
  }
}
