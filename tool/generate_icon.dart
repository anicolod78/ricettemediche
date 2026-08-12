// Genera gli asset dell'icona dell'app in assets/icon/.
// Esegui con:  dart run tool/generate_icon.dart
//
// Design: capsula tozza bicolore (metà chiara + metà blu scuro) con una croce
// bianca sul lato scuro, su fondo blu.
//
// Produce:
//  - icon.png            : icona completa (fondo blu + capsula), per
//                          iOS/web/windows/macos e come fallback Android.
//  - icon_foreground.png : solo la capsula su trasparente (icona adattiva
//                          Android), con margine di sicurezza.
//  - icon_background.png : fondo blu pieno per l'icona adattiva Android.
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;

// Colori
final _blueBg = img.ColorRgb8(30, 123, 224); // #1E7BE0
final _light = img.ColorRgb8(220, 235, 255); // #DCEBFF (lato chiaro)
final _dark = img.ColorRgb8(14, 78, 158); //   #0E4E9E (lato scuro)
final _white = img.ColorRgba8(255, 255, 255, 255);

void _fillBlue(img.Image im) {
  img.fillRect(
    im,
    x1: 0,
    y1: 0,
    x2: size - 1,
    y2: size - 1,
    color: _blueBg,
  );
}

/// Disegna la capsula bicolore + croce bianca, centrata in [cx],[cy].
/// [w] e [h] sono larghezza e altezza della capsula (h pari => estremi tondi).
void _drawCapsule(
  img.Image im, {
  required int cx,
  required int cy,
  required int w,
  required int h,
}) {
  final int r = h ~/ 2; // raggio degli estremi arrotondati
  final int left = cx - w ~/ 2;
  final int right = cx + w ~/ 2;
  final int top = cy - h ~/ 2;
  final int bottom = cy + h ~/ 2;

  // 1) Capsula intera nel colore chiaro (estremi arrotondati).
  img.fillRect(
    im,
    x1: left,
    y1: top,
    x2: right,
    y2: bottom,
    color: _light,
    radius: r,
  );

  // 2) Metà destra scura: rettangolo interno (bordo sinistro dritto) + estremo
  //    destro tondo tramite un cerchio.
  img.fillRect(
    im,
    x1: cx,
    y1: top,
    x2: right - r,
    y2: bottom,
    color: _dark,
  );
  img.fillCircle(
    im,
    x: right - r,
    y: cy,
    radius: r,
    color: _dark,
    antialias: true,
  );

  // 3) Sottile divisore blu al centro.
  final int div = (h * 0.03).round().clamp(2, 12);
  img.fillRect(
    im,
    x1: cx - div ~/ 2,
    y1: top + 2,
    x2: cx + div ~/ 2,
    y2: bottom - 2,
    color: _blueBg,
  );

  // 4) Croce bianca centrata sul lato scuro (a 3/4 della capsula).
  final int crossCx = cx + w ~/ 4;
  final int arm = (h * 0.28).round(); // mezza lunghezza braccio
  final int thick = (h * 0.105).round(); // mezzo spessore
  final int cr = thick;
  // barra verticale
  img.fillRect(
    im,
    x1: crossCx - thick,
    y1: cy - arm,
    x2: crossCx + thick,
    y2: cy + arm,
    color: _white,
    radius: cr,
  );
  // barra orizzontale
  img.fillRect(
    im,
    x1: crossCx - arm,
    y1: cy - thick,
    x2: crossCx + arm,
    y2: cy + thick,
    color: _white,
    radius: cr,
  );
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  const c = size ~/ 2;

  // 1) Icona completa: fondo blu + capsula (con buon margine).
  final full = img.Image(width: size, height: size, numChannels: 4);
  _fillBlue(full);
  _drawCapsule(full, cx: c, cy: c, w: 600, h: 300);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(full));

  // 2) Foreground adattivo: capsula un po' più piccola su trasparente,
  //    così resta nella "safe zone" dell'icona adattiva Android.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  _drawCapsule(fg, cx: c, cy: c, w: 520, h: 260);
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) Background adattivo: fondo blu pieno.
  final bg = img.Image(width: size, height: size, numChannels: 4);
  _fillBlue(bg);
  File('assets/icon/icon_background.png').writeAsBytesSync(img.encodePng(bg));

  stdout.writeln('Icone generate in assets/icon/');
}
