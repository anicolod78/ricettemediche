// Genera gli asset dell'icona dell'app in assets/icon/ a partire da
// assets/icon/medicinali.png.
// Esegui con:  dart run tool/generate_icon.dart
//
// medicinali.png ha lo sfondo teal "cotto" nell'immagine. Qui il contenuto
// (capsula, busta, orologio) viene scontornato dallo sfondo, ritagliato al suo
// riquadro utile e ricomposto su un fondo teal UNIFORME. Lo sfondo omogeneo e
// il contenuto ingrandito danno un'icona pulita anche in versione adattiva
// Android.
//
// Produce:
//  - icon.png            : contenuto su fondo teal pieno (iOS/web/win/macos + fallback).
//  - icon_foreground.png : contenuto su trasparente (adattiva Android).
//  - icon_background.png : fondo teal pieno (adattiva Android).
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;

// Fondo teal uniforme, coerente con l'immagine originale.
final _teal = img.ColorRgb8(17, 108, 109);

/// Riconosce i pixel dello sfondo teal (R basso, G/B medi e simili tra loro).
bool _isBackground(num r, num g, num b) {
  return r < 70 && g > 70 && g < 150 && b > 70 && b < 150 &&
      (g - r) > 35 && (g - b).abs() < 30;
}

/// Rende trasparente lo sfondo teal, poi ritaglia al riquadro del contenuto.
img.Image _extractContent(img.Image src) {
  final keyed = img.Image(width: src.width, height: src.height, numChannels: 4);
  int minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      if (_isBackground(p.r, p.g, p.b)) {
        keyed.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        keyed.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  return img.copyCrop(
    keyed,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// Scala [content] in modo che il lato lungo sia [frac] della tela.
img.Image _scaledToFrac(img.Image content, double frac) {
  final target = (size * frac).round();
  final scale = target / (content.width > content.height
      ? content.width
      : content.height);
  return img.copyResize(
    content,
    width: (content.width * scale).round(),
    height: (content.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
}

void _center(img.Image dst, img.Image src) {
  img.compositeImage(
    dst,
    src,
    dstX: (dst.width - src.width) ~/ 2,
    dstY: (dst.height - src.height) ~/ 2,
  );
}

void main() {
  final src = img.decodePng(
    File('assets/icon/medicinali.png').readAsBytesSync(),
  );
  if (src == null) {
    stderr.writeln('Impossibile leggere assets/icon/medicinali.png');
    exit(1);
  }

  final content = _extractContent(src);

  // 1) Icona completa: contenuto (~80% del lato) su fondo teal pieno.
  final full = img.Image(width: size, height: size, numChannels: 3);
  img.fillRect(full, x1: 0, y1: 0, x2: size - 1, y2: size - 1, color: _teal);
  _center(full, _scaledToFrac(content, 0.80));
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(full));

  // 2) Foreground adattivo: contenuto (~70% del lato) su trasparente.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  _center(fg, _scaledToFrac(content, 0.70));
  File('assets/icon/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) Background adattivo: teal pieno e uniforme.
  final bg = img.Image(width: size, height: size, numChannels: 3);
  img.fillRect(bg, x1: 0, y1: 0, x2: size - 1, y2: size - 1, color: _teal);
  File('assets/icon/icon_background.png').writeAsBytesSync(img.encodePng(bg));

  stdout.writeln('Icone generate da medicinali.png in assets/icon/');
}
