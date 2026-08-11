class Medicine {
  final int id; // ID unico (es. uuid o timestamp) per gestire le notifiche
  final String name;
  final String description;
  final String dosage;
  bool isSelected;
  // Nuovi campi per il promemoria
  DateTime? startTime; // Data e ora della prima assunzione
  int? intervalHours; // Frequenza (es. ogni 8 ore)
  bool isReminderActive; // Stato del promemoria

  Medicine({
    required this.id,
    required this.name,
    required this.description,
    required this.dosage,
    this.isSelected = false,
    this.startTime,
    this.intervalHours,
    this.isReminderActive = false,
  });

  // Conversione da/verso JSON per il salvataggio
  Map<String, dynamic> toJson() {
    return {
      'id': id == -1
          ? DateTime.now().millisecondsSinceEpoch.remainder(100000)
          : id,
      'name': name,
      'description': description,
      'dosage': dosage,
      'isSelected': false,
      'startTime': startTime?.toIso8601String(), // Salviamo come stringa ISO
      'intervalHours': intervalHours,
      'isReminderActive': isReminderActive,
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? -1,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      dosage: json['dosage'] ?? '',
      isSelected: false,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'])
          : null,
      intervalHours: json['intervalHours'],
      isReminderActive: json['isReminderActive'] ?? false,
    );
  }
}
