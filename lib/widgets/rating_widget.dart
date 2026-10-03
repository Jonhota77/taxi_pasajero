import 'package:flutter/material.dart';

/// Widget reutilizable de calificación con estrellas + comentario opcional.
/// Se usa dentro de trip_status_screen.dart cuando el viaje ya se completó.
class RatingWidget extends StatefulWidget {
  final Future<void> Function(int score, String? comment) onSubmit;
  const RatingWidget({super.key, required this.onSubmit});

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  int _selectedScore = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  Future<void> _submit() async {
    if (_selectedScore == 0) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _selectedScore,
        _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo enviar la calificacion")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text("Gracias por tu calificacion", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text("¿Como estuvo tu viaje?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return IconButton(
                icon: Icon(
                  starValue <= _selectedScore ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _selectedScore = starValue),
              );
            }),
          ),
          if (_selectedScore > 0) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Comentario (opcional)",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Enviar calificacion", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
