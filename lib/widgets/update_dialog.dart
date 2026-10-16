import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';

// Muestra el dialogo de actualizacion disponible. Si info.forceUpdate es
// true, el dialogo no se puede cerrar sin actualizar (ni con el boton
// atras ni tocando fuera de el) -- para fixes criticos.
Future<void> showUpdateDialog(BuildContext context, AppVersionInfo info) async {
  bool downloading = false;
  double progress = 0.0;

  await showDialog(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return PopScope(
            canPop: !info.forceUpdate,
            child: AlertDialog(
              backgroundColor: AppTheme.navyDeep,
              title: const Text(
                "Nueva version disponible",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Version ${info.versionName}",
                    style: const TextStyle(color: AppTheme.yellow, fontWeight: FontWeight.bold),
                  ),
                  if (info.changelog != null && info.changelog!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(info.changelog!, style: const TextStyle(color: Colors.white70)),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress > 0 ? progress : null, color: AppTheme.yellow, backgroundColor: Colors.white24),
                    const SizedBox(height: 8),
                    Text(
                      progress > 0 ? "${(progress * 100).toStringAsFixed(0)}%" : "Descargando...",
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: downloading
                  ? []
                  : [
                      if (!info.forceUpdate)
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text("Mas tarde", style: TextStyle(color: Colors.white54)),
                        ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.yellow, foregroundColor: AppTheme.navy),
                        onPressed: () async {
                          setState(() => downloading = true);
                          try {
                            await UpdateService().downloadAndInstall(
                              info,
                              onProgress: (p) => setState(() => progress = p),
                            );
                          } catch (e) {
                            setState(() => downloading = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text("Error al descargar: $e")),
                              );
                            }
                          }
                        },
                        child: const Text("Actualizar", style: TextStyle(color: Colors.black)),
                      ),
                    ],
            ),
          );
        },
      );
    },
  );
}