import 'package:flutter/material.dart';

import '../models.dart';
import '../portal_service.dart';
import '../theme.dart';

/// Historial de notificaciones del cliente: inicio de trámite, cambios de
/// área y finalización. Al abrir la pantalla se marcan como leídas.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<MobileNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await portal.getNotifications();
      if (!mounted) return;
      setState(() => _items = items);
      // Marcar leídas en segundo plano (la campanita se limpia al volver).
      portal.markNotificationsRead().catchError((_) {});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _empty()
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _card(_items[index]),
                  ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.notifications_none, size: 48, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(
          _error ?? 'Aún no tienes notificaciones.\nTe avisaremos de cada avance de tus trámites.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slateSoft, fontSize: 13.5),
        ),
      ],
    );
  }

  Widget _card(MobileNotification n) {
    final (icon, bg, fg) = switch (n.type) {
      'CASE_STARTED' => (Icons.rocket_launch_outlined, AppColors.primarySoft, AppColors.primaryDark),
      'AREA_CHANGED' => (Icons.swap_horiz, AppColors.warningBg, AppColors.warningText),
      'CASE_FINISHED' => (Icons.check_circle_outline, AppColors.successBg, AppColors.successText),
      _ => (Icons.notifications_none, AppColors.surfaceSoft, AppColors.slate),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 21, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                n.read ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.message,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.slate, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(n.createdAt),
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
