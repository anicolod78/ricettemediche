// Genera gli asset dell'icona dell'app in assets/icon/.
// Esegui con:  dart run tool/generate_icon.dart
//
// Produce:
//  - icon.png            : icona completa (sfondo con gradiente + croce), usata
//                          per iOS/web/windows/macos e come fallback Android.
//  - icon_foreground.png : solo la croce su sfondo trasparente, per l'icona
//                          adattiva Android (il contenuto resta piccolo così
//                          non appare "troppo grande" dopo lo zoom del sistema).
//  - icon_background.png : sfondo con gradiente per l'icona adattiva Android.
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;

// Colori del gradiente (blu, coerente col tema dell'app) e della croce.
const _topR = 33, _topG = 150, _topB = 243; // #2196F3
const _botR = 21, _botG = 101, _botB = 192; // #1565C0

void _fillGradient(img.Image im) {
  for (int y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = (_topR + (_botR - _topR) * t).round();
    final g = (_topG + (_botG - _topG) * t).round();
    final b = (_topB + (_botB - _topB) * t).round();
    img.fillRect(
      im,
      x1: 0,
      y1: y,
      x2: size - 1,
      y2: y,
      color: img.ColorRgb8(r, g, b),
    );
  }
}

/// Disegna una croce medica bianca centrata.
/// [arm] = mezza lunghezza del braccio, [thick] = mezzo spessore.
void _drawCross(img.Image im, {required int arm, required int thick}) {
  const c = size ~/ 2;
  final white = img.ColorRgba8(255, 255, 255, 255);
  final radius = thick * 0.9;
  // Barra verticale
  img.fillRect(
    im,
    x1: c - thick,
    y1: c - arm,
    x2: c + thick,
    y2: c + arm,
    color: white,
    radius: radius,
  );
  // Barra orizzontale
  img.fillRect(
    im,
    x1: c - arm,
    y1: c - thick,
    x2: c + arm,
    y2: c + thick,
    color: white,
    radius: radius,
  );
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // 1) Icona completa: gradiente a tutto campo + croce con buon margine (~46%).
  final full = img.Image(width: size, height: size, numChannels: 4);
  _fillGradient(full);
  _drawCross(full, arm: 235, thick: 68);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(full));

  // 2) Foreground adattivo: croce piccola su trasparente (~41%), così dopo lo
  //    zoom dell'icona adattiva Android non risulta sovradimensionata.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  _drawCross(fg, arm: 210, thick: 62);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) Background adattivo: solo il gradiente.
  final bg = img.Image(width: size, height: size, numChannels: 4);
  _fillGradient(bg);
  File('assets/icon/icon_background.png').writeAsBytesSync(img.encodePng(bg));

  stdout.writeln('Icone generate in assets/icon/');
}
