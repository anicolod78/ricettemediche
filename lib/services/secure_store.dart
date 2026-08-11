import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Archivio cifrato per i dati personali/sanitari (pazienti, medicine, ecc.).
///
/// Su Android usa AES-GCM con chiave protetta dall'Android Keystore
/// (RSA-OAEP). I dati non sono quindi più leggibili in chiaro dal filesystem.
class SecureStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // Opzioni predefinite v11: AES-GCM + RSA-OAEP, con resetOnError attivo
    // (in caso di errore keystore evita crash resettando lo storage).
    aOptions: AndroidOptions(),
  );

  /// Chiavi dei dati sensibili gestiti in modo cifrato.
  static const List<String> sensitiveKeys = [
    'patients',
    'medicines',
    'selected_patient_id',
    'doctor_email',
  ];

  /// Chiavi obsolete di vecchie versioni che contenevano dati sensibili in
  /// chiaro (es. 'patient_name' = codice fiscale del paziente selezionato).
  /// Non sono più usate: vanno rimosse dalle SharedPreferences.
  static const List<String> _obsoletePlaintextKeys = ['patient_name'];

  static Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // In caso di errore keystore non blocchiamo l'app.
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  /// Migrazione una-tantum: sposta i dati sensibili dalle SharedPreferences
  /// (in chiaro) allo storage cifrato e rimuove la vecchia copia in chiaro.
  /// Dopo la prima esecuzione le chiavi non sono più nelle prefs, quindi
  /// agli avvii successivi non fa nulla.
  static Future<void> migrateFromPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in sensitiveKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.getString(key);
      if (value != null) {
        // Non sovrascrivere eventuali dati già presenti nello storage cifrato.
        final existing = await read(key);
        if (existing == null) {
          await write(key, value);
        }
      }
      await prefs.remove(key); // elimina la copia in chiaro
    }

    // Rimuove le chiavi obsolete in chiaro (dati sensibili di vecchie versioni).
    for (final key in _obsoletePlaintextKeys) {
      await prefs.remove(key);
    }
  }
}
