class Patient {
  /// Identificatore univoco e stabile del paziente.
  /// Serve come valore della dropdown e per ripristinare la selezione:
  /// il codice fiscale non va bene perché è opzionale e può ripetersi.
  final String id;
  final String firstName;
  final String lastName;
  final String fiscalCode;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.fiscalCode = "",
  });

  /// Crea un nuovo paziente generando un id univoco.
  factory Patient.create({
    required String firstName,
    required String lastName,
    String fiscalCode = "",
  }) {
    return Patient(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      firstName: firstName,
      lastName: lastName,
      fiscalCode: fiscalCode,
    );
  }

  // Conversione da/verso JSON per il salvataggio
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'fiscalCode': fiscalCode,
    };
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      // Migrazione dati vecchi senza 'id': ricaviamo un id deterministico.
      id:
          (json['id'] as String?) ??
          '${json['lastName'] ?? ''}_${json['firstName'] ?? ''}_${json['fiscalCode'] ?? ''}',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fiscalCode: json['fiscalCode'] ?? '',
    );
  }

  String getName() {
    return '$lastName $firstName $fiscalCode'.trim();
  }
}
