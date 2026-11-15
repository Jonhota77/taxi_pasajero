import 'package:flutter/material.dart';
import '../config.dart';
import '../theme/app_theme.dart';

/// Foto redonda del conductor. Si no tiene foto (o no carga) muestra un icono.
class DriverAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const DriverAvatar({super.key, this.photoUrl, this.size = 64});

  static String? fullUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith("http") ? url : "${AppConfig.apiBaseUrl}$url";
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        color: AppTheme.navySurface,
        child: Icon(Icons.person, color: AppTheme.textMutedOnDark, size: size * 0.6),
      );

  @override
  Widget build(BuildContext context) {
    final url = fullUrl(photoUrl);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
                loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(),
              ),
      ),
    );
  }
}

/// Tarjeta "Tu conductor": foto, nombre. Al tocar la foto se ve en grande.
class DriverCard extends StatelessWidget {
  final String? name;
  final String? photoUrl;

  const DriverCard({super.key, this.name, this.photoUrl});

  void _zoom(BuildContext context) {
    final url = DriverAvatar.fullUrl(photoUrl);
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _zoom(context),
            child: DriverAvatar(photoUrl: photoUrl, size: 64),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tu conductor", style: TextStyle(color: AppTheme.textMutedOnDark, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  name ?? "Conductor",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
