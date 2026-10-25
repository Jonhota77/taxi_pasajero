import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio local: si la persona lleva 4 dias sin abrir la app, le llega
/// una notificacion. Funciona sin servidor: cada vez que la app se abre o se
/// manda a segundo plano, se reprograma el aviso para dentro de 4 dias (usa
/// siempre el mismo ID, asi que el anterior se reemplaza). Mientras la
/// persona use la app, el aviso nunca llega. Nunca lanza errores hacia
/// afuera: si algo falla, la app sigue igual que antes, solo sin el aviso.
class InactivityReminder {
  InactivityReminder._();
  static final InactivityReminder instance = InactivityReminder._();

  static const int _notificationId = 7700;
  static const int _days = 4;
  static const String _channelId = 'bipy_recordatorios';
  static const String _channelName = 'Recordatorios';
  static const String _channelDescription = 'Te avisa si llevas varios dias sin usar la app.';
  static const String _title = 'Te extrañamos en Bipy';
  static const String _body = 'Hace días no te vemos. Vuelve a solicitar un taxi con Bipy.';
  static const String _askedKey = 'inactivity_reminder_permission_asked';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _suspended = false;

  Future<bool> _init() async {
    if (_ready) return true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      ),
    );
    _ready = true;
    return true;
  }

  /// Pide el permiso de notificaciones una sola vez (Android 13 o superior).
  Future<void> _askPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) == true) return;
    await prefs.setBool(_askedKey, true);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Fecha del aviso: dentro de 4 dias, pero en horario razonable
  /// (entre 9:00 y 20:00; si cae fuera, se mueve a las 10:00).
  // Solo para pruebas: flutter build apk --dart-define=REMINDER_TEST_MINUTES=2
  // hace que el aviso llegue a los 2 minutos. Sin esa opcion (0) se usan los 4 dias.
  static const int _testMinutes = int.fromEnvironment('REMINDER_TEST_MINUTES', defaultValue: 0);
  // Solo diagnostico: --dart-define=REMINDER_DEBUG=true muestra para cuando quedo programado el aviso real.
  static const bool _debugOn = bool.fromEnvironment('REMINDER_DEBUG', defaultValue: false);

  DateTime _target() {
    if (_testMinutes > 0) return DateTime.now().add(const Duration(minutes: _testMinutes));
    var t = DateTime.now().add(const Duration(days: _days));
    if (t.hour < 9) {
      t = DateTime(t.year, t.month, t.day, 10);
    } else if (t.hour >= 20) {
      final next = t.add(const Duration(days: 1));
      t = DateTime(next.year, next.month, next.day, 10);
    }
    return t;
  }

  /// Solo en el APK de prueba: muestra al instante el estado del aviso.
  Future<void> _debug(String text) async {
    if (_testMinutes <= 0 && !_debugOn) return;
    try {
      await _plugin.show(
        id: 7701,
        title: 'Prueba de aviso',
        body: text,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(_channelId, _channelName, channelDescription: _channelDescription),
        ),
      );
    } catch (_) {}
  }

  /// (Re)programa el aviso para dentro de 4 dias.
  Future<void> schedule() async {
    if (kIsWeb || _suspended) return;
    try {
      if (!await _init()) return;
      await _askPermissionOnce();
      final when = _target();
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: _title,
        body: _body,
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      if (_testMinutes > 0 || _debugOn) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await android?.areNotificationsEnabled();
        final pending = await _plugin.pendingNotificationRequests();
        await _debug('Programado para ${when.day}/${when.month} ${when.hour}:${when.minute.toString().padLeft(2, '0')} (ahora: ${DateTime.now().day}/${DateTime.now().month} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}). Permiso: $enabled. Pendientes: ${pending.length}');
      }
    } catch (e) {
      debugPrint('InactivityReminder.schedule fallo: $e');
      await _debug('Error: $e');
    }
  }

  /// Cancela el aviso pendiente.
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      if (!await _init()) return;
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('InactivityReminder.cancel fallo: $e');
    }
  }
}
