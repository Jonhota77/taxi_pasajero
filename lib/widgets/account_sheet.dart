import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/change_password_screen.dart';

/// Hoja "Mi cuenta": cambiar contraseña y cerrar sesion.
Future<void> showAccountSheet(BuildContext context, {required VoidCallback onLogout}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppTheme.navy),
            title: const Text("Cambiar contraseña"),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text("Cerrar sesión"),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onLogout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
