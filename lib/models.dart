/// Modelos del portal móvil — espejo de los DTOs del backend:
///   - /api/mobile/login → MobileSession + lista de CaseSummary
///   - ConsultationCaseDTO → CaseSummary (timeline por áreas + etapas)
///   - /api/mobile/policies → MobilePolicy + FormFieldDef (form dinámico)
///   - /ai/classify-intake → IntakeClassification (Módulo 3)
library;

String _s(dynamic v) => v?.toString() ?? '';

String? _sn(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Sesión del cliente autenticado (correo + CI verificados en el backend).
class MobileSession {
  final String customerId;
  final String name;
  final String email;
  final String ci;

  const MobileSession({
    required this.customerId,
    required this.name,
    required this.email,
    required this.ci,
  });

  factory MobileSession.fromJson(Map<String, dynamic> json) => MobileSession(
        customerId: _s(json['customerId']),
        name: _s(json['name']),
        email: _s(json['email']),
        ci: _s(json['ci']),
      );
}

/// Progreso de un área (departamento) dentro del trámite.
/// status: COMPLETED | CURRENT | PENDING — círculos de la línea de tiempo.
class LaneProgress {
  final String laneName;
  final String status;

  const LaneProgress({required this.laneName, required this.status});

  factory LaneProgress.fromJson(Map<String, dynamic> json) => LaneProgress(
        laneName: _s(json['laneName']),
        status: _s(json['status']).toUpperCase(),
      );
}

/// Etapa actualmente activa (en espera / en proceso) del trámite.
class CurrentStage {
  final String activityName;
  final String? laneName;
  final String state;
  final String? claimedByName;
  final String? since;

  const CurrentStage({
    required this.activityName,
    this.laneName,
    required this.state,
    this.claimedByName,
    this.since,
  });

  factory CurrentStage.fromJson(Map<String, dynamic> json) => CurrentStage(
        activityName: _s(json['activityName']),
        laneName: _sn(json['laneName']),
        state: _s(json['state']).toUpperCase(),
        claimedByName: _sn(json['claimedByName']),
        since: _sn(json['since']),
      );
}

/// Un trámite del cliente con su progreso (mismo shape que Consultas).
class CaseSummary {
  final String caseId;
  final String code;
  final String? policyName;
  final String status; // activo | finalizado
  final String? startedAt;
  final String? finishedAt;
  final List<LaneProgress> lanesProgress;
  final List<CurrentStage> currentStages;

  const CaseSummary({
    required this.caseId,
    required this.code,
    this.policyName,
    required this.status,
    this.startedAt,
    this.finishedAt,
    required this.lanesProgress,
    required this.currentStages,
  });

  bool get isFinished =>
      status.toLowerCase() == 'finalizado' || status.toUpperCase() == 'COMPLETED';

  factory CaseSummary.fromJson(Map<String, dynamic> json) => CaseSummary(
        caseId: _s(json['caseId']),
        code: _s(json['code']),
        policyName: _sn(json['policyName']),
        status: _s(json['status']),
        startedAt: _sn(json['startedAt']),
        finishedAt: _sn(json['finishedAt']),
        lanesProgress: ((json['lanesProgress'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LaneProgress.fromJson)
            .toList(),
        currentStages: ((json['currentStages'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CurrentStage.fromJson)
            .toList(),
      );
}

/// Campo del formulario inicial dinámico (subset del FormFieldDTO).
class FormFieldDef {
  final String name;
  final String label;
  final String type;
  final bool required;
  final List<String> options;

  const FormFieldDef({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
  });

  factory FormFieldDef.fromJson(Map<String, dynamic> json) => FormFieldDef(
        name: _s(json['name']),
        label: _sn(json['label']) ?? _s(json['name']),
        type: _s(json['type']).toLowerCase(),
        required: json['required'] == true,
        options: ((json['options'] as List?) ?? const [])
            .map((o) => o.toString())
            .toList(),
      );
}

/// Política disponible para iniciar trámite desde la app.
class MobilePolicy {
  final String id;
  final String name;
  final String? description;
  final List<FormFieldDef> startFormFields;

  const MobilePolicy({
    required this.id,
    required this.name,
    this.description,
    required this.startFormFields,
  });

  factory MobilePolicy.fromJson(Map<String, dynamic> json) {
    final def = json['startFormDefinition'];
    final fields = (def is Map<String, dynamic> ? def['fields'] as List? : null) ?? const [];
    return MobilePolicy(
      id: _s(json['id']),
      name: _s(json['name']),
      description: _sn(json['description']),
      startFormFields: fields
          .whereType<Map<String, dynamic>>()
          .map(FormFieldDef.fromJson)
          .toList(),
    );
  }
}

/// Resultado del clasificador inteligente (Módulo 3).
class IntakeClassification {
  final String? policyId;
  final String? policyName;
  final String confidence; // ALTA | MEDIA | BAJA
  final String reply;
  final List<IntakeAlternative> alternatives;

  const IntakeClassification({
    this.policyId,
    this.policyName,
    required this.confidence,
    required this.reply,
    required this.alternatives,
  });

  factory IntakeClassification.fromJson(Map<String, dynamic> json) =>
      IntakeClassification(
        policyId: _sn(json['policyId']),
        policyName: _sn(json['policyName']),
        confidence: _s(json['confidence']).toUpperCase(),
        reply: _s(json['reply']),
        alternatives: ((json['alternatives'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(IntakeAlternative.fromJson)
            .toList(),
      );
}

class IntakeAlternative {
  final String policyId;
  final String? policyName;

  const IntakeAlternative({required this.policyId, this.policyName});

  factory IntakeAlternative.fromJson(Map<String, dynamic> json) =>
      IntakeAlternative(
        policyId: _s(json['policyId']),
        policyName: _sn(json['policyName']),
      );
}
