import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

/// Permite al usuario cambiar su propia contraseña (por ejemplo, despues de
/// recibir una temporal de la secretaria).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _authService = AuthService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final next = _newController.text;
    String? err;
    if (current.isEmpty) {
      err = "Escribe tu contraseña actual (o la temporal que te dieron).";
    } else if (next.length < 6) {
      err = "La contraseña nueva debe tener al menos 6 caracteres.";
    } else if (next.length > 72) {
      err = "La contraseña nueva no puede pasar de 72 caracteres.";
    } else if (next != _confirmController.text) {
      err = "Las contraseñas nuevas no coinciden.";
    } else if (next == current) {
      err = "La contraseña nueva debe ser distinta de la actual.";
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await _authService.changePassword(currentPassword: current, newPassword: next);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Contraseña actualizada")),
    );
    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: !_show,
      enableSuggestions: false,
      autocorrect: false,
      style: const TextStyle(color: AppTheme.textDark, fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
          tooltip: _show ? "Ocultar" : "Mostrar",
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Cambiar contraseña"),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Si la secretaría te dio una contraseña temporal, escríbela como contraseña actual y elige una nueva que solo tú conozcas.",
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
              ),
              const SizedBox(height: 20),
              _field(_currentController, "Contraseña actual"),
              const SizedBox(height: 16),
              _field(_newController, "Contraseña nueva (mínimo 6)"),
              const SizedBox(height: 16),
              _field(_confirmController, "Repite la contraseña nueva"),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.navy))
                    : const Text("Guardar contraseña"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
