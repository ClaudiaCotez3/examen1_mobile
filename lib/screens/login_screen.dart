import 'package:flutter/material.dart';

import '../models.dart';
import '../portal_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'new_case_screen.dart';

/// Login del cliente: correo + CI (los mismos datos que dio al abrir su
/// primer trámite en atención al cliente). Sin contraseñas — el cliente
/// no es un usuario del backoffice.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _ciCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _ciCtrl.dispose();
    super.dispose();
  }

  /// Cliente NUEVO: va directo al flujo inteligente (describe su problema,
  /// la IA le asigna el trámite y llena el registro inicial — ahí pone su
  /// correo y CI, que serán sus credenciales de ingreso).
  Future<void> _startNewCase() async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => const NewCaseScreen(guest: true)),
    );
    if (!mounted) return;
    if (result is String && result.isNotEmpty) {
      // Volvió con el correo usado en el formulario → lo dejamos listo.
      _emailCtrl.text = result;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Trámite iniciado! Ingresa con el correo y CI que registraste.',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<CaseSummary> cases =
          await portal.login(_emailCtrl.text.trim(), _ciCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(initialCases: cases),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Marca ───────────────────────────────────────────
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.account_tree_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Mis Trámites',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Consulta el estado de tus trámites e inicia nuevos sin ir a la oficina.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: AppColors.slateSoft),
                  ),
                  const SizedBox(height: 28),

                  // ── Tarjeta de login ────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Ingresa con los datos de tu trámite',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Usa el correo y CI que diste al abrir tu trámite.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.mail_outline,
                                    size: 20, color: AppColors.muted),
                              ),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) return 'Ingresa tu correo';
                                if (!value.contains('@')) {
                                  return 'Correo inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _ciCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cédula / CI',
                                prefixIcon: Icon(Icons.badge_outlined,
                                    size: 20, color: AppColors.muted),
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Ingresa tu CI'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 18, color: AppColors.dangerText),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.dangerText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Ingresar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Cliente nuevo: inicia su primer trámite desde la app ──
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '¿Eres nuevo?',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _startNewCase,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ai,
                      side: const BorderSide(color: Color(0xFFC4B5FD)),
                      backgroundColor: AppColors.aiSoft,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'Iniciar un nuevo trámite',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuéntanos tu problema por texto o audio y te asignamos '
                    'el trámite adecuado, sin ir a la oficina.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
