import 'package:flutter/material.dart';

import '../models.dart';
import '../portal_service.dart';
import '../push_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'new_case_screen.dart';
import 'notifications_screen.dart';

/// Dashboard del cliente: sus trámites con el flujo en el que se
/// encuentran — línea de tiempo por áreas (igual que la vista "Consultas"
/// del frontend) y etapas activas con su estado (en espera / en proceso /
/// finalizado).
class DashboardScreen extends StatefulWidget {
  final List<CaseSummary> initialCases;

  const DashboardScreen({super.key, required this.initialCases});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<CaseSummary> _cases = widget.initialCases;
  bool _refreshing = false;
  String? _error;
  String? _expandedCaseId;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    // Push: registra este dispositivo para avisos del trámite y refresca
    // la campanita cuando llega una notificación con la app abierta.
    PushService.instance.registerWithBackend();
    PushService.instance.onNotificationReceived = () {
      if (mounted) _loadUnread();
    };
    _loadUnread();
  }

  @override
  void dispose() {
    PushService.instance.onNotificationReceived = null;
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final items = await portal.getNotifications();
      if (mounted) {
        setState(() => _unread = items.where((n) => !n.read).length);
      }
    } catch (_) {
      /* la campanita no es crítica */
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await _loadUnread();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final cases = await portal.getCases();
      if (mounted) setState(() => _cases = cases);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _logout() {
    portal.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _newCase() async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewCaseScreen()),
    );
    if (started == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final name = portal.session?.name ?? 'Cliente';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Trámites'),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.slateSoft,
              ),
            ),
          ],
        ),
        actions: [
          // Campanita de notificaciones con contador de no leídas
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: _openNotifications,
                icon: const Icon(Icons.notifications_none,
                    color: AppColors.slate),
              ),
              if (_unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 17),
                    child: Text(
                      _unread > 9 ? '9+' : '$_unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh, color: AppColors.slate),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.slate),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newCase,
        backgroundColor: AppColors.ai,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Nuevo trámite'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _cases.isEmpty
            ? _emptyState()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _cases.length + (_error != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (_error != null && index == 0) return _errorBanner();
                  final c = _cases[index - (_error != null ? 1 : 0)];
                  return _caseCard(c);
                },
              ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.folder_open, size: 48, color: AppColors.muted),
        const SizedBox(height: 12),
        const Text(
          'Aún no tienes trámites registrados.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slateSoft, fontSize: 14),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toca «Nuevo trámite» para iniciar uno desde la app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _errorBanner(),
          ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.dangerText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(fontSize: 12.5, color: AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de trámite ────────────────────────────────────────────────

  Widget _caseCard(CaseSummary c) {
    final expanded = _expandedCaseId == c.caseId;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() => _expandedCaseId = expanded ? null : c.caseId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.code,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.policyName ?? 'Trámite',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(c),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Inicio: ${_formatDate(c.startedAt)}'
                '${c.finishedAt != null ? '  ·  Fin: ${_formatDate(c.finishedAt)}' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (expanded) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                if (c.lanesProgress.isNotEmpty) ...[
                  _lanesTimeline(c.lanesProgress),
                  const SizedBox(height: 14),
                ],
                _stagesSection(c),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(CaseSummary c) {
    final finished = c.isFinished;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: finished ? AppColors.successBg : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        finished ? 'Finalizado' : 'Activo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: finished ? AppColors.successText : AppColors.primaryDark,
        ),
      ),
    );
  }

  // ── Línea de tiempo por áreas (círculos, como Consultas) ─────────────

  Widget _lanesTimeline(List<LaneProgress> lanes) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < lanes.length; i++) ...[
            _laneNode(lanes[i], i),
            if (i < lanes.length - 1)
              Container(
                width: 26,
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: lanes[i].status == 'COMPLETED'
                      ? AppColors.successText
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _laneNode(LaneProgress lane, int index) {
    Color bg;
    Color fg;
    Widget inner;
    switch (lane.status) {
      case 'COMPLETED':
        bg = AppColors.successText;
        fg = Colors.white;
        inner = const Icon(Icons.check, size: 18, color: Colors.white);
        break;
      case 'CURRENT':
        bg = AppColors.primary;
        fg = Colors.white;
        inner = const Icon(Icons.autorenew, size: 18, color: Colors.white);
        break;
      default:
        bg = AppColors.surfaceSoft;
        fg = AppColors.muted;
        inner = Text(
          '${index + 1}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
        );
    }
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: lane.status == 'PENDING' ? AppColors.border : bg,
              width: 2,
            ),
          ),
          child: inner,
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 76,
          child: Text(
            lane.laneName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
          ),
        ),
      ],
    );
  }

  // ── Etapas actuales ───────────────────────────────────────────────────

  Widget _stagesSection(CaseSummary c) {
    if (c.isFinished) {
      return _hintRow(Icons.check_circle_outline,
          'Trámite finalizado: ya no hay etapas activas.');
    }
    if (c.currentStages.isEmpty) {
      return _hintRow(
          Icons.hourglass_empty, 'No hay etapas activas en este momento.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESTADO ACTUAL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.slateSoft,
          ),
        ),
        const SizedBox(height: 8),
        for (final stage in c.currentStages)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage.activityName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    _stageChip(stage.state),
                  ],
                ),
                const SizedBox(height: 8),
                // Área (departamento) donde está el trámite ahora mismo
                Row(
                  children: [
                    const Icon(Icons.apartment_outlined,
                        size: 15, color: AppColors.slateSoft),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Área: ${stage.laneName ?? '—'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.slate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Operador que está atendiendo el trámite
                Row(
                  children: [
                    Icon(
                      stage.claimedByName != null
                          ? Icons.support_agent
                          : Icons.person_off_outlined,
                      size: 15,
                      color: stage.claimedByName != null
                          ? AppColors.primaryDark
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stage.claimedByName != null
                            ? 'Te atiende: ${stage.claimedByName}'
                            : 'Esperando que un operador tome tu trámite',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: stage.claimedByName != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: stage.claimedByName != null
                              ? AppColors.primaryDark
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (stage.since != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        'Desde: ${_formatDate(stage.since)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _stageChip(String state) {
    final s = state.toUpperCase();
    Color bg;
    Color fg;
    String label;
    if (s.contains('PROGRESS') || s == 'EN_PROCESO') {
      bg = AppColors.primarySoft;
      fg = AppColors.primaryDark;
      label = 'En proceso';
    } else if (s.contains('COMPLETED') || s == 'FINALIZADO') {
      bg = AppColors.successBg;
      fg = AppColors.successText;
      label = 'Finalizada';
    } else {
      bg = AppColors.warningBg;
      fg = AppColors.warningText;
      label = 'En espera';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _hintRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slateSoft),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
  }
}
