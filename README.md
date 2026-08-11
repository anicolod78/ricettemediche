# Ricette mediche

App Flutter per gestire un elenco di medicinali e inviare rapidamente al proprio
medico la **richiesta di ricette via email**, con **promemoria di assunzione**
(notifiche locali).

Pensata per un uso personale/familiare: aiuta chi segue la terapia di un
familiare a tenere l'elenco dei farmaci aggiornato e a richiedere le ricette
senza riscrivere ogni volta la stessa email.

## Funzionalità

- **Elenco medicinali** con nome, dosaggio e descrizione; aggiunta, modifica, eliminazione.
- **Anagrafica pazienti** (nome, cognome, codice fiscale) con selezione rapida.
- **Richiesta ricette via email**: si selezionano i farmaci e l'app apre il
  client di posta con oggetto e corpo precompilati verso l'email del medico.
- **Testi email configurabili**: oggetto, testo iniziale e finale personalizzabili
  (segnaposto `{paziente}` sostituito col nominativo). Menu ⋮ → *Testi email*.
- **Promemoria di assunzione**: notifiche locali ricorrenti a intervalli
  configurabili (1/4/6/8/12/24 ore), riprogrammate anche dopo il riavvio.
- **Notifica di prova** per verificare il recapito (menu ⋮ → *Notifica di prova*).
- **Tema chiaro/scuro**.

## Sicurezza dei dati

- I dati sensibili (pazienti, medicine, email del medico, paziente selezionato)
  sono salvati in **storage cifrato** (`flutter_secure_storage`: AES-GCM con
  chiave protetta dall'Android Keystore). Non sono leggibili in chiaro dal
  filesystem.
- **Backup di sistema disabilitato** (`android:allowBackup="false"`), così i
  dati non finiscono in chiaro nei backup ADB/cloud.
- Il codice sorgente **non contiene dati personali**: i dati reali vivono solo
  cifrati sul dispositivo.
- I dati non lasciano mai il telefono: l'invio avviene tramite il client email
  dell'utente (`mailto:`), senza alcun server.

## Requisiti

- Flutter SDK (Dart `^3.8.1`)
- Android: **minSdk 24** (richiesto dallo storage cifrato), target/compile SDK 36

## Compilazione ed esecuzione

```bash
flutter pub get

# Esecuzione su dispositivo/emulatore collegato
flutter run

# Build release (APK) — target privilegiato Android
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

> Nota: la build Windows non è supportata in modo affidabile a causa di
> un'incompatibilità del plugin `flutter_local_notifications_windows` con le
> toolchain MSVC recenti. Il target di riferimento è **Android**.

### Icona dell'app

Le icone sono generate da uno script riproducibile:

```bash
dart run tool/generate_icon.dart   # rigenera gli asset in assets/icon/
dart run flutter_launcher_icons     # applica le icone alle piattaforme
```

## Struttura del progetto

```
lib/
  main.dart                      # avvio app, tema, init notifiche difensivo
  models/
    medicine.dart                # modello medicinale (+ JSON)
    patient.dart                 # modello paziente con id univoco (+ JSON)
  services/
    notification_service.dart    # notifiche locali (schedulazione ricorrente)
    secure_store.dart            # storage cifrato + migrazione dati
  widgets/
    medicine_list.dart           # schermata principale e dialog
tool/
  generate_icon.dart             # generatore icone
```

## Note sulle notifiche (Android)

Le notifiche locali sono recapitate dal sistema (AlarmManager) **anche ad app
chiusa**: non serve tenere l'app attiva in background. Perché arrivino puntuali a
telefono bloccato, però, su molti dispositivi occorre **escludere l'app
dall'ottimizzazione batteria** (Impostazioni → App → Ricette mediche → Batteria →
*Nessuna restrizione*), ed eventualmente attivare l'*avvio automatico*.

## Stato

Progetto ad uso personale. Firmato con la chiave di debug: per una distribuzione
"pulita" (o pubblicazione) sarebbe necessaria una chiave di firma dedicata.
