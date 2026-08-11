import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:richiesta_ricette/models/medicine.dart';
import 'package:richiesta_ricette/models/patient.dart';
import 'package:richiesta_ricette/services/notification_service.dart';
import 'package:richiesta_ricette/services/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicineListScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const MedicineListScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final TextEditingController _doctorEmailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Patient> patients = [];
  Patient? _selectedPatientName;
  List<Medicine> medicines = [];
  bool _isLoading = true;

  // Testi configurabili dell'email. {paziente} viene sostituito col nominativo.
  static const String _defaultSubject = 'Richiesta ricette';
  static const String _defaultHeader =
      'Buongiorno,\nper {paziente}\nLa prego preparare ricette per:';
  static const String _defaultFooter = 'Grazie\n\nDistinti saluti';

  String _emailSubject = _defaultSubject;
  String _emailHeader = _defaultHeader;
  String _emailFooter = _defaultFooter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Carica i dati salvati
  Future<void> _loadData() async {
    // Migra i dati sensibili eventualmente ancora in chiaro nelle
    // SharedPreferences verso lo storage cifrato (una-tantum).
    await SecureStore.migrateFromPrefsIfNeeded();

    final prefs = await SharedPreferences.getInstance();

    // Carica i pazienti (storage cifrato)
    final patientsJson = await SecureStore.read('patients');
    if (patientsJson != null) {
      final List<dynamic> patientsList = json.decode(patientsJson);
      patients = patientsList.map((json) => Patient.fromJson(json)).toList();
    }

    // Carica i medicinali (storage cifrato)
    final medicinesJson = await SecureStore.read('medicines');
    if (medicinesJson != null) {
      final List<dynamic> medicinesList = json.decode(medicinesJson);
      medicines = medicinesList
          .map((json) => Medicine.fromJson(json))
          .toList();

      // Riattiva le notifiche per i farmaci con promemoria attivo.
      // Usa medicine.id (coerente con creazione/modifica/cancellazione).
      for (final medicine in medicines) {
        if (medicine.isReminderActive && medicine.startTime != null) {
          NotificationService.scheduleMedicine(
            id: medicine.id,
            name: medicine.name,
            startDateTime: medicine.startTime!,
            intervalHours: medicine.intervalHours ?? 8,
          );
        }
      }
    }

    // Ripristina il paziente selezionato (per id univoco) e l'email del medico.
    final savedPatientId = await SecureStore.read('selected_patient_id');
    if (savedPatientId != null) {
      for (final p in patients) {
        if (p.id == savedPatientId) {
          _selectedPatientName = p;
          break;
        }
      }
    }
    _doctorEmailController.text = await SecureStore.read('doctor_email') ?? '';

    // Testi email configurabili (non sensibili: restano nelle SharedPreferences)
    _emailSubject = prefs.getString('email_subject') ?? _defaultSubject;
    _emailHeader = prefs.getString('email_header') ?? _defaultHeader;
    _emailFooter = prefs.getString('email_footer') ?? _defaultFooter;

    setState(() {
      _isLoading = false;
    });
  }

  // Salva i testi configurabili dell'email
  Future<void> _saveEmailTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_subject', _emailSubject);
    await prefs.setString('email_header', _emailHeader);
    await prefs.setString('email_footer', _emailFooter);
  }

  // Dialog per configurare i testi (oggetto, intestazione, chiusura) dell'email.
  void _showEmailSettingsDialog() {
    final subjectController = TextEditingController(text: _emailSubject);
    final headerController = TextEditingController(text: _emailHeader);
    final footerController = TextEditingController(text: _emailFooter);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Testi email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Oggetto',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: headerController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Testo iniziale',
                    helperText: 'Usa {paziente} per inserire il nominativo',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tra testo iniziale e finale vengono inseriti automaticamente '
                  'l\'elenco dei medicinali e le eventuali note.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: footerController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Testo finale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Ripristina i testi predefiniti nei campi (senza ancora salvare)
                subjectController.text = _defaultSubject;
                headerController.text = _defaultHeader;
                footerController.text = _defaultFooter;
              },
              child: Text('Ripristina'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final s = subjectController.text.trim();
                  _emailSubject = s.isEmpty ? _defaultSubject : s;
                  _emailHeader = headerController.text;
                  _emailFooter = footerController.text;
                });
                _saveEmailTemplates();
                Navigator.of(context).pop();
              },
              child: Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  // Invia una notifica di prova (tra pochi secondi) per verificare che i
  // promemoria vengano recapitati sul dispositivo.
  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notifica di prova programmata: dovrebbe arrivare tra pochi secondi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile inviare la notifica: $e')),
      );
    }
  }

  // Salva i pazienti (storage cifrato)
  Future<void> _savePatients() async {
    final patientsJson = json.encode(patients.map((m) => m.toJson()).toList());
    await SecureStore.write('patients', patientsJson);
  }

  // Salva i medicinali (storage cifrato)
  Future<void> _saveMedicines() async {
    final medicinesJson = json.encode(
      medicines.map((m) => m.toJson()).toList(),
    );
    await SecureStore.write('medicines', medicinesJson);
  }

  // Salva le informazioni del paziente e medico
  // Restituisce il paziente con l'id dato, o null se non trovato.
  Patient? _findPatientById(String? id) {
    if (id == null) return null;
    for (final p in patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _saveUserInfo() async {
    // Dati sensibili → storage cifrato
    if (_selectedPatientName != null) {
      await SecureStore.write('selected_patient_id', _selectedPatientName!.id);
    }
    await SecureStore.write('doctor_email', _doctorEmailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Richiesta Ricette Mediche'),
          actions: [
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: widget.onThemeToggle,
              tooltip: widget.isDarkMode ? 'Tema chiaro' : 'Tema scuro',
            ),
          ],
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Richiesta Ricette Mediche'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
            tooltip: widget.isDarkMode ? 'Tema chiaro' : 'Tema scuro',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddMedicineDialog,
            tooltip: 'Aggiungi medicinale',
          ),
          PopupMenuButton<String>(
            tooltip: 'Altre opzioni',
            onSelected: (value) {
              if (value == 'email_settings') {
                _showEmailSettingsDialog();
              } else if (value == 'test_notification') {
                _sendTestNotification();
              }
            },
            itemBuilder: (context) {
              // Colore icone adattato al tema (nel menu, non alla barra):
              // altrimenti ereditano il bianco dell'AppBar e in light mode
              // risultano invisibili.
              final menuIconColor = Theme.of(context).colorScheme.onSurface;
              return [
                PopupMenuItem(
                  value: 'email_settings',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 20, color: menuIconColor),
                      SizedBox(width: 8),
                      Text('Testi email'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'test_notification',
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 20,
                        color: menuIconColor,
                      ),
                      SizedBox(width: 8),
                      Text('Notifica di prova'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Sezione dati paziente e medico
          Container(
            padding: EdgeInsets.all(16.0),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: DropdownButtonFormField<String>(
                        // La key cambia quando cambia l'insieme dei pazienti o
                        // la selezione, così la dropdown si rigenera in modo
                        // corretto dopo aggiunta/eliminazione.
                        key: ValueKey(
                          '${patients.length}-${_selectedPatientName?.id ?? 'none'}',
                        ),
                        items: patients.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text('${p.lastName} ${p.firstName}'),
                          );
                        }).toList(),
                        initialValue: _selectedPatientName?.id,
                        decoration: InputDecoration(
                          labelText: 'Nome Paziente',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        hint: Text('Seleziona un paziente'),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPatientName = _findPatientById(newValue);
                          });
                          _saveUserInfo();
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_add),
                      onPressed: _showAddPatientDialog,
                      tooltip: 'Aggiungi paziente',
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert),
                      tooltip: 'Gestisci paziente',
                      // Attivo solo se c'è un paziente selezionato.
                      enabled: _selectedPatientName != null,
                      onSelected: (value) {
                        final p = _selectedPatientName;
                        if (p == null) return;
                        if (value == 'edit') {
                          _showEditPatientDialog(p);
                        } else if (value == 'delete') {
                          _showDeletePatientDialog(p);
                        }
                      },
                      itemBuilder: (context) {
                        final menuIconColor =
                            Theme.of(context).colorScheme.onSurface;
                        return [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: menuIconColor),
                                SizedBox(width: 8),
                                Text('Modifica paziente'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Elimina paziente',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _doctorEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email del Medico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => _saveUserInfo(),
                ),
              ],
            ),
          ),

          // Lista medicinali
          Expanded(
            child: medicines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Nessun medicinale nella lista',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tocca + per aggiungere medicinali',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: medicines.length,
                    itemBuilder: (context, index) {
                      final medicine = medicines[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: CheckboxListTile(
                          title: Row(
                            children: [
                              // Usiamo Flexible per evitare errori se il nome è troppo lungo
                              Flexible(
                                child: Text(
                                  medicine.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Mostra il campanello solo se il promemoria è attivo
                              if (medicine.isReminderActive == true) ...[
                                SizedBox(width: 8), // Spazio tra nome e icona
                                Icon(
                                  Icons.notifications_active,
                                  color: Colors
                                      .red[600], // Un colore rosso per il campanello
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dosaggio: ${medicine.dosage}',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          value: medicine.isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              medicine.isSelected = value ?? false;
                            });
                            _saveMedicines();
                          },
                          activeColor: Colors.blue[700],
                          secondary: PopupMenuButton<String>(
                            onSelected: (String result) {
                              if (result == 'edit') {
                                _showEditMedicineDialog(medicine, index);
                              } else if (result == 'delete') {
                                _showDeleteMedicineDialog(medicine, index);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Modifica'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Elimina',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Note aggiuntive
          Container(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Note aggiuntive (opzionale)',
                border: OutlineInputBorder(),
                hintText: 'Inserisci eventuali note per il medico...',
              ),
            ),
          ),

          // Bottone invio
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _sendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Invia Richiesta al Medico',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _sendRequest() {
    // Controlla se ci sono medicinali selezionati
    final selectedMedicines = medicines.where((m) => m.isSelected).toList();

    if (selectedMedicines.isEmpty) {
      _showErrorDialog('Seleziona almeno un medicinale');
      return;
    }

    if (_doctorEmailController.text.trim().isEmpty) {
      _showErrorDialog('Inserisci l\'email del medico');
      return;
    }

    if (!_isValidEmail(_doctorEmailController.text.trim())) {
      _showErrorDialog('L\'email del medico non è valida');
      return;
    }

    if (_selectedPatientName == null) {
      _showErrorDialog('Seleziona il nome del paziente');
      return;
    }

    _sendEmail(selectedMedicines);
  }

  // Validazione essenziale del formato email.
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  void _sendEmail(List<Medicine> selectedMedicines) async {
    final String subject = _emailSubject;

    final buffer = StringBuffer();
    // Intestazione (con sostituzione del segnaposto {paziente})
    buffer.writeln(
      _emailHeader.replaceAll('{paziente}', _selectedPatientName!.getName()),
    );
    buffer.writeln();

    // Elenco medicinali
    for (final medicine in selectedMedicines) {
      buffer.writeln('- ${medicine.name} ${medicine.dosage}');
    }

    // Note aggiuntive (opzionali)
    if (_notesController.text.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(_notesController.text.trim());
    }

    // Chiusura
    buffer.writeln();
    buffer.write(_emailFooter);

    final String body = buffer.toString();

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _doctorEmailController.text.trim(),
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final bool launched = await launchUrl(emailUri);
      if (!mounted) return;
      if (launched) {
        _showSuccessDialog();
      } else {
        _showErrorDialog('Impossibile aprire l\'app email');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Errore nell\'invio: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Errore'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Successo'),
          content: Text('Richiesta inviata con successo!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetForm();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      for (var medicine in medicines) {
        medicine.isSelected = false;
      }
      _notesController.clear();
    });
  }

  // Funzioni per gestire i pazienti
  void _showAddPatientDialog() {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();
    final TextEditingController fiscalCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Aggiungi Paziente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: fiscalCodeController,
                  decoration: InputDecoration(
                    labelText: 'Codice fiscale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (firstNameController.text.isNotEmpty &&
                    lastNameController.text.isNotEmpty) {
                  setState(() {
                    patients.add(
                      Patient.create(
                        firstName: firstNameController.text.trim(),
                        lastName: lastNameController.text.trim(),
                        fiscalCode: fiscalCodeController.text.trim(),
                      ),
                    );
                  });
                  _savePatients();
                  Navigator.of(context).pop();
                } else {
                  _showErrorDialog('Compila tutti i campi');
                }
              },
              child: Text('Aggiungi'),
            ),
          ],
        );
      },
    );
  }

  // Modifica un paziente esistente (mantenendone l'id univoco).
  void _showEditPatientDialog(Patient patient) {
    final firstNameController = TextEditingController(text: patient.firstName);
    final lastNameController = TextEditingController(text: patient.lastName);
    final fiscalCodeController = TextEditingController(text: patient.fiscalCode);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Modifica Paziente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: fiscalCodeController,
                  decoration: InputDecoration(
                    labelText: 'Codice fiscale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (firstNameController.text.trim().isEmpty ||
                    lastNameController.text.trim().isEmpty) {
                  _showErrorDialog('Compila nome e cognome');
                  return;
                }
                final updated = Patient(
                  id: patient.id, // stesso id: è una modifica, non un nuovo paziente
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  fiscalCode: fiscalCodeController.text.trim(),
                );
                setState(() {
                  final index = patients.indexWhere((p) => p.id == patient.id);
                  if (index != -1) patients[index] = updated;
                  // Aggiorna il riferimento se era il paziente selezionato.
                  if (_selectedPatientName?.id == patient.id) {
                    _selectedPatientName = updated;
                  }
                });
                _savePatients();
                Navigator.of(context).pop();
              },
              child: Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  // Elimina un paziente (con conferma).
  void _showDeletePatientDialog(Patient patient) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Elimina Paziente'),
          content: Text(
            'Sei sicuro di voler eliminare "${patient.lastName} ${patient.firstName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  patients.removeWhere((p) => p.id == patient.id);
                  // Se era il paziente selezionato, azzera la selezione.
                  if (_selectedPatientName?.id == patient.id) {
                    _selectedPatientName = null;
                    SecureStore.delete('selected_patient_id');
                  }
                });
                _savePatients();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Elimina'),
            ),
          ],
        );
      },
    );
  }

  // Funzioni per gestire i medicinali
  void _showAddMedicineDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController dosageController = TextEditingController();

    // Variabili per il promemoria
    bool isReminderActive = false;
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();
    int selectedInterval = 8;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // StatefulBuilder è necessario per aggiornare la UI dentro il Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Aggiungi Medicinale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome medicinale',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: dosageController,
                      decoration: InputDecoration(
                        labelText: 'Dosaggio (es. 500mg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SwitchListTile(
                      title: Text(
                        "Attiva Promemoria",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isReminderActive,
                      activeThumbColor: Colors.blue[700],
                      onChanged: (bool value) {
                        setStateDialog(() => isReminderActive = value);
                      },
                    ),

                    if (isReminderActive) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Data inizio: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                        ),
                        trailing: Icon(
                          Icons.calendar_today,
                          color: Colors.blue[700],
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate!,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (d != null) setStateDialog(() => selectedDate = d);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Orario prima dose: ${selectedTime!.format(context)}",
                        ),
                        trailing: Icon(
                          Icons.access_time,
                          color: Colors.blue[700],
                        ),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: selectedTime!,
                          );
                          if (t != null) setStateDialog(() => selectedTime = t);
                        },
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: selectedInterval,
                        decoration: InputDecoration(labelText: "Ripeti ogni"),
                        items: [1, 4, 6, 8, 12, 24]
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text("$h ore"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => selectedInterval = v!),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        dosageController.text.isNotEmpty) {
                      // Creiamo il DateTime combinato per il salvataggio
                      DateTime? finalStartTime;
                      if (isReminderActive &&
                          selectedDate != null &&
                          selectedTime != null) {
                        finalStartTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );
                      }

                      final int newId = DateTime.now().millisecondsSinceEpoch
                          .remainder(100000);

                      setState(() {
                        medicines.add(
                          Medicine(
                            id: newId,
                            name: nameController.text.trim(),
                            description: descriptionController.text.trim(),
                            dosage: dosageController.text.trim(),
                            isReminderActive: isReminderActive,
                            startTime: finalStartTime,
                            intervalHours: isReminderActive
                                ? selectedInterval
                                : null,
                          ),
                        );
                      });
                      _saveMedicines();

                      if (isReminderActive && finalStartTime != null) {
                        NotificationService.scheduleMedicine(
                          id: newId,
                          name: nameController.text.trim(),
                          startDateTime: finalStartTime,
                          intervalHours: selectedInterval,
                        );
                      }

                      Navigator.of(context).pop();
                    } else {
                      _showErrorDialog('Compila tutti i campi');
                    }
                  },
                  child: Text('Aggiungi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMedicineDialog(Medicine medicine, int index) {
    final TextEditingController nameController = TextEditingController(
      text: medicine.name,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: medicine.description,
    );
    final TextEditingController dosageController = TextEditingController(
      text: medicine.dosage,
    );

    // Inizializza con i dati esistenti della medicina
    bool isReminderActive = medicine.isReminderActive;
    DateTime? selectedDate = medicine.startTime ?? DateTime.now();
    TimeOfDay? selectedTime = medicine.startTime != null
        ? TimeOfDay.fromDateTime(medicine.startTime!)
        : TimeOfDay.now();
    int selectedInterval = medicine.intervalHours ?? 8;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // StatefulBuilder è necessario per aggiornare la UI dentro il Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Modifica Medicinale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome medicinale',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: dosageController,
                      decoration: InputDecoration(
                        labelText: 'Dosaggio (es. 500mg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SwitchListTile(
                      title: Text(
                        "Attiva Promemoria",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isReminderActive,
                      activeThumbColor: Colors.blue[700],
                      onChanged: (bool value) {
                        setStateDialog(() => isReminderActive = value);
                      },
                    ),

                    if (isReminderActive) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Data inizio: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                        ),
                        trailing: Icon(
                          Icons.calendar_today,
                          color: Colors.blue[700],
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate!,
                            firstDate: DateTime.now().subtract(
                              Duration(days: 365),
                            ), // Permette di vedere date passate se già impostate
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (d != null) setStateDialog(() => selectedDate = d);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Orario prima dose: ${selectedTime!.format(context)}",
                        ),
                        trailing: Icon(
                          Icons.access_time,
                          color: Colors.blue[700],
                        ),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: selectedTime!,
                          );
                          if (t != null) setStateDialog(() => selectedTime = t);
                        },
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: selectedInterval,
                        decoration: InputDecoration(labelText: "Ripeti ogni"),
                        items: [1, 4, 6, 8, 12, 24]
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text("$h ore"),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => selectedInterval = v!),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        dosageController.text.isNotEmpty) {
                      DateTime? finalStartTime;
                      if (isReminderActive &&
                          selectedDate != null &&
                          selectedTime != null) {
                        finalStartTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );
                      }
                      setState(() {
                        medicines[index] = Medicine(
                          id: medicine.id,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          dosage: dosageController.text.trim(),
                          isSelected: medicine.isSelected,
                          isReminderActive: isReminderActive,
                          startTime: finalStartTime,
                          intervalHours: isReminderActive
                              ? selectedInterval
                              : null,
                        );
                      });

                      // Gestione aggiornamento notifiche
                      // 1. Cancelliamo le vecchie notifiche per sicurezza
                      NotificationService.cancelMedicine(medicine.id);

                      // 2. Se è ancora attivo, riprogrammiamo con i nuovi dati
                      if (isReminderActive && finalStartTime != null) {
                        NotificationService.scheduleMedicine(
                          id: medicine.id,
                          name: nameController.text,
                          startDateTime: finalStartTime,
                          intervalHours: selectedInterval,
                        );
                      }

                      _saveMedicines();
                      Navigator.of(context).pop();
                    } else {
                      _showErrorDialog('Compila tutti i campi');
                    }
                  },
                  child: Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteMedicineDialog(Medicine medicine, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Elimina Medicinale'),
          content: Text('Sei sicuro di voler eliminare "${medicine.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                // Cancella anche le eventuali notifiche pianificate.
                NotificationService.cancelMedicine(medicine.id);
                setState(() {
                  medicines.removeAt(index);
                });
                _saveMedicines();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Elimina'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _doctorEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
