import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models.dart';
import '../portal_service.dart';
import '../theme.dart';

/// Módulo 3 — Clasificación Inteligente de Trámites.
///
/// Flujo en 2 pasos:
///   1. El cliente DESCRIBE su necesidad en lenguaje natural. La IA
///      identifica la política de negocio adecuada del catálogo
///      (POST /ai/classify-intake) y responde en tono cercano.
///   2. La app carga el FORMULARIO INICIAL de ese trámite y el cliente lo
///      envía (POST /api/mobile/start-case). Sus datos de identidad
///      (nombre/correo/CI) ya van implícitos — el backend los inyecta
///      desde la sesión verificada, por eso no se le vuelven a pedir.
class NewCaseScreen extends StatefulWidget {
  /// true cuando entra un cliente NUEVO desde el login (sin sesión): el
  /// formulario muestra también los campos de identidad (nombre, correo,
  /// CI) — esos datos crean su registro y serán sus credenciales.
  final bool guest;

  const NewCaseScreen({super.key, this.guest = false});

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _descriptionCtrl = TextEditingController();

  bool _classifying = false;
  bool _loadingForm = false;
  bool _submitting = false;
  String? _error;

  // ── Dictado por voz (speech_to_text, es-ES) ──────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;

  IntakeClassification? _classification;
  MobilePolicy? _policy;

  // Estado del formulario dinámico
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textCtrls = {};
  final Map<String, dynamic> _values = {};

  /// Campos reservados de identidad. Con sesión, el backend los completa
  /// solo (se ocultan); en modo invitado SÍ se muestran — son el registro
  /// inicial del cliente y sus futuras credenciales de ingreso.
  static const _reservedFields = {'cliente_nombre', 'cliente_email', 'cliente_ci'};

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es_ES',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (result) {
        // Transcripción en vivo dentro del campo de texto.
        setState(() => _descriptionCtrl.text = result.recognizedWords);
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _descriptionCtrl.dispose();
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Paso 1: clasificar la necesidad ──────────────────────────────────

  Future<void> _classify() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    }
    final text = _descriptionCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Cuéntanos qué necesitas para poder ayudarte.');
      return;
    }
    setState(() {
      _classifying = true;
      _error = null;
      _classification = null;
      _policy = null;
    });
    try {
      final result = await portal.classifyIntake(text);
      if (!mounted) return;
      setState(() => _classification = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  // ── Paso 2: cargar formulario del trámite elegido ────────────────────

  Future<void> _selectPolicy(String policyId) async {
    setState(() {
      _loadingForm = true;
      _error = null;
    });
    try {
      final policy = await portal.getPolicy(policyId);
      if (!mounted) return;
      _textCtrls.clear();
      _values.clear();
      setState(() => _policy = policy);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingForm = false);
    }
  }

  List<FormFieldDef> get _visibleFields => (_policy?.startFormFields ?? [])
      .where((f) => widget.guest || !_reservedFields.contains(f.name))
      .toList();

  Future<void> _submit() async {
    final policy = _policy;
    if (policy == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    final data = <String, dynamic>{};
    for (final field in _visibleFields) {
      final value = _values[field.name];
      switch (field.type) {
        case 'number':
          final raw = (value ?? '').toString().trim();
          if (raw.isNotEmpty) data[field.name] = num.tryParse(raw) ?? raw;
          break;
        case 'checkbox':
          data[field.name] = value == true;
          break;
        case 'tags':
          final raw = (value ?? '').toString();
          data[field.name] = raw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          break;
        case 'file':
          // Los adjuntos se entregan luego en oficina / vía operador;
          // se registra la lista vacía para cumplir el esquema.
          data[field.name] = <Map<String, dynamic>>[];
          break;
        default:
          final raw = (value ?? '').toString().trim();
          if (raw.isNotEmpty) data[field.name] = raw;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final String code;
      final String guestEmail = (data['cliente_email'] ?? '').toString().trim();
      if (widget.guest) {
        final guestCi = (data['cliente_ci'] ?? '').toString().trim();
        code = await portal.startCaseAsGuest(
          policy.id,
          data,
          email: guestEmail,
          ci: guestCi,
        );
      } else {
        code = await portal.startCase(policy.id, data);
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: const Icon(Icons.check_circle,
              color: AppColors.successText, size: 44),
          title: const Text('¡Trámite iniciado!'),
          content: Text(
            widget.guest
                ? 'Tu trámite quedó registrado con el código\n$code\n\n'
                    'Desde ahora puedes ingresar a la app con el correo y CI '
                    'que registraste para seguir su avance.'
                : 'Tu trámite quedó registrado con el código\n$code\n\n'
                    'Puedes seguir su avance desde tu panel.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.slate),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) {
        // Invitado → vuelve al login con su correo listo para ingresar;
        // cliente con sesión → el dashboard refresca sus trámites.
        Navigator.of(context).pop(widget.guest ? guestEmail : true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo trámite')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_policy == null) ...[
                _describeCard(),
                if (_classification != null) ...[
                  const SizedBox(height: 14),
                  _classificationCard(_classification!),
                ],
              ] else ...[
                _formHeader(_policy!),
                const SizedBox(height: 14),
                _dynamicForm(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Paso 1 — descripción de la necesidad
  Widget _describeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.aiSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: AppColors.ai, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '¿Qué necesitas?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Descríbelo con tus palabras y te indicamos el trámite adecuado. '
              'Por ejemplo: «se me dañó el medidor de luz y necesito que lo revisen».',
              style: TextStyle(fontSize: 12.5, color: AppColors.slateSoft),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _listening
                    ? 'Escuchando… habla con normalidad'
                    : 'Escribe aquí tu necesidad… o dictala con el micrófono',
                enabledBorder: _listening
                    ? const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide:
                            BorderSide(color: Color(0xFFEF4444), width: 2),
                      )
                    : null,
              ),
            ),
            if (_listening) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.graphic_eq, size: 16, color: AppColors.dangerText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escuchando… toca el micrófono de nuevo cuando termines.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.dangerText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                // Dictado por voz
                Container(
                  decoration: BoxDecoration(
                    color: _listening ? AppColors.dangerBg : AppColors.aiSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _listening
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFDDD6FE),
                    ),
                  ),
                  child: IconButton(
                    tooltip: _speechAvailable
                        ? (_listening ? 'Detener dictado' : 'Dictar por voz')
                        : 'Dictado no disponible en este dispositivo',
                    onPressed:
                        _speechAvailable && !_classifying ? _toggleListening : null,
                    icon: Icon(
                      _listening ? Icons.mic_off : Icons.mic,
                      color: _listening ? AppColors.dangerText : AppColors.ai,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: AppColors.ai),
                    onPressed: _classifying ? null : _classify,
                    icon: _classifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_classifying
                        ? 'Identificando tu trámite…'
                        : 'Identificar mi trámite'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Paso 1.5 — respuesta de la IA
  Widget _classificationCard(IntakeClassification result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.aiSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                result.reply,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.slate, height: 1.45),
              ),
            ),
            if (result.policyId != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySofter,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined,
                        color: AppColors.primaryDark, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.policyName ?? 'Trámite sugerido',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Confianza: ${result.confidence.toLowerCase()}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.slateSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadingForm
                    ? null
                    : () => _selectPolicy(result.policyId!),
                icon: _loadingForm
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Continuar con este trámite'),
              ),
            ],
            if (result.alternatives.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'También podría ser:',
                style: TextStyle(fontSize: 12, color: AppColors.slateSoft),
              ),
              const SizedBox(height: 6),
              for (final alt in result.alternatives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    onPressed:
                        _loadingForm ? null : () => _selectPolicy(alt.policyId),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(alt.policyName ?? alt.policyId),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Paso 2 — encabezado + formulario dinámico
  Widget _formHeader(MobilePolicy policy) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined,
                color: AppColors.primaryDark, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    widget.guest
                        ? 'Completa tu registro inicial. Con el correo y CI '
                            'que pongas aquí podrás ingresar a la app.'
                        : 'Completa los datos para iniciar tu trámite. Tu '
                            'nombre, correo y CI ya están incluidos.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.slateSoft),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _policy = null;
                        _error = null;
                      }),
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dynamicForm() {
    final fields = _visibleFields;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Este trámite no requiere datos adicionales. '
                    'Confirma para iniciarlo.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.slateSoft),
                  ),
                ),
              for (final field in fields) ...[
                _fieldWidget(field),
                const SizedBox(height: 14),
              ],
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 17),
                label:
                    Text(_submitting ? 'Iniciando trámite…' : 'Iniciar trámite'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Render de un campo según su tipo ──────────────────────────────────

  Widget _fieldWidget(FormFieldDef field) {
    switch (field.type) {
      case 'select':
        return DropdownButtonFormField<String>(
          initialValue: _values[field.name] as String?,
          decoration: InputDecoration(labelText: _labelOf(field)),
          items: [
            for (final opt in field.options)
              DropdownMenuItem(value: opt, child: Text(opt)),
          ],
          validator: (v) => field.required && (v == null || v.isEmpty)
              ? 'Selecciona una opción'
              : null,
          onChanged: (v) => _values[field.name] = v,
        );

      case 'radio':
        return FormField<String>(
          validator: (_) => field.required &&
                  ((_values[field.name] as String?)?.isEmpty ?? true)
              ? 'Selecciona una opción'
              : null,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_labelOf(field),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.slate)),
              for (final opt in field.options)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt, style: const TextStyle(fontSize: 13.5)),
                  value: opt,
                  // ignore: deprecated_member_use
                  groupValue: _values[field.name] as String?,
                  activeColor: AppColors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    setState(() => _values[field.name] = v);
                    state.didChange(v);
                  },
                ),
              if (state.hasError)
                Text(state.errorText!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.dangerText)),
            ],
          ),
        );

      case 'checkbox':
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
          title: Text(field.label, style: const TextStyle(fontSize: 13.5)),
          value: _values[field.name] == true,
          onChanged: (v) => setState(() => _values[field.name] = v ?? false),
        );

      case 'date':
        final ctrl = _ctrlFor(field.name);
        return TextFormField(
          controller: ctrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: _labelOf(field),
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.muted),
          ),
          validator: (v) => field.required && (v == null || v.isEmpty)
              ? 'Selecciona una fecha'
              : null,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) {
              final iso =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              ctrl.text = iso;
              _values[field.name] = iso;
            }
          },
          onSaved: (_) => _values[field.name] = ctrl.text,
        );

      case 'file':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${field.label}: los documentos los entregas luego en '
                  'oficina o los sube el operador a tu expediente.',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.slateSoft),
                ),
              ),
            ],
          ),
        );

      case 'textarea':
        return _textField(field, maxLines: 4);

      case 'number':
        return _textField(field,
            keyboardType: const TextInputType.numberWithOptions(decimal: true));

      case 'tags':
        return _textField(field, hint: 'Separa los valores con comas');

      default: // text, datetime y tipos no soportados caen a texto simple
        return _textField(field);
    }
  }

  Widget _textField(FormFieldDef field,
      {int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return TextFormField(
      controller: _ctrlFor(field.name),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: _labelOf(field), hintText: hint),
      validator: (v) => field.required && (v ?? '').trim().isEmpty
          ? 'Este campo es obligatorio'
          : null,
      onSaved: (v) => _values[field.name] = v ?? '',
      onChanged: (v) => _values[field.name] = v,
    );
  }

  TextEditingController _ctrlFor(String name) =>
      _textCtrls.putIfAbsent(name, TextEditingController.new);

  String _labelOf(FormFieldDef field) =>
      field.required ? '${field.label} *' : field.label;

  Widget _errorBanner(String message) {
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
              message,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
  }
}
