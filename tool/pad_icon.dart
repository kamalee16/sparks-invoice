// Run with: dart tool/pad_icon.dart
// Pure Dart — no external packages needed.
// Reads spark_logo.png, embeds it centered on a larger transparent canvas,
// and writes spark_logo_padded.png ready for flutter_launcher_icons.

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

// ── Minimal PNG decoder/encoder ───────────────────────────────────────────────

// Decode a PNG into raw RGBA pixels.
// Returns (width, height, Uint8List pixels) or throws.
(int, int, Uint8List) decodePng(Uint8List bytes) {
  // Validate PNG signature
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != sig[i]) throw Exception('Not a PNG file');
  }

  int width = 0, height = 0, bitDepth = 0, colorType = 0;
  final idatChunks = <Uint8List>[];
  var pos = 8;

  while (pos < bytes.length) {
    final length = _readUint32(bytes, pos); pos += 4;
    final type   = String.fromCharCodes(bytes.sublist(pos, pos + 4)); pos += 4;
    final data   = bytes.sublist(pos, pos + length); pos += length;
    pos += 4; // CRC

    if (type == 'IHDR') {
      width     = _readUint32(data, 0);
      height    = _readUint32(data, 4);
      bitDepth  = data[8];
      colorType = data[9];
    } else if (type == 'IDAT') {
      idatChunks.add(data);
    } else if (type == 'IEND') {
      break;
    }
  }

  if (bitDepth != 8) throw Exception('Only 8-bit PNG supported (got $bitDepth)');
  // colorType: 2=RGB, 6=RGBA
  final channels = (colorType == 6) ? 4 : (colorType == 2) ? 3 : throw Exception('Unsupported colorType $colorType');

  // Concatenate IDAT chunks and zlib-decompress
  final compressed = Uint8List(idatChunks.fold(0, (s, c) => s + c.length));
  var off = 0;
  for (final c in idatChunks) { compressed.setRange(off, off + c.length, c); off += c.length; }
  final raw = _zlibDecompress(compressed);

  // Reconstruct pixels with PNG filter
  final stride  = width * channels;
  final pixels  = Uint8List(width * height * 4); // always RGBA output
  var rawPos = 0;
  final prev = Uint8List(stride);

  for (var y = 0; y < height; y++) {
    final filter = raw[rawPos++];
    final row    = raw.sublist(rawPos, rawPos + stride); rawPos += stride;
    _applyFilter(filter, row, prev, channels);
    for (var x = 0; x < width; x++) {
      final pi = (y * width + x) * 4;
      final ri = x * channels;
      pixels[pi]     = row[ri];
      pixels[pi + 1] = row[ri + 1];
      pixels[pi + 2] = row[ri + 2];
      pixels[pi + 3] = channels == 4 ? row[ri + 3] : 255;
    }
    prev.setRange(0, stride, row);
  }
  return (width, height, pixels);
}

void _applyFilter(int filter, Uint8List row, Uint8List prev, int bpp) {
  switch (filter) {
    case 0: break; // None
    case 1: // Sub
      for (var i = bpp; i < row.length; i++) row[i] = (row[i] + row[i - bpp]) & 0xFF;
    case 2: // Up
      for (var i = 0; i < row.length; i++) row[i] = (row[i] + prev[i]) & 0xFF;
    case 3: // Average
      for (var i = 0; i < row.length; i++) {
        final a = i >= bpp ? row[i - bpp] : 0;
        row[i] = (row[i] + ((a + prev[i]) >> 1)) & 0xFF;
      }
    case 4: // Paeth
      for (var i = 0; i < row.length; i++) {
        final a = i >= bpp ? row[i - bpp] : 0;
        final b = prev[i];
        final c = i >= bpp ? prev[i - bpp] : 0;
        row[i] = (row[i] + _paeth(a, b, c)) & 0xFF;
      }
  }
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

// Encode RGBA pixels to PNG bytes
Uint8List encodePng(int width, int height, Uint8List pixels) {
  final raw = BytesBuilder();
  final prev = Uint8List(width * 4);
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter None
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.addByte(pixels[i]);
      raw.addByte(pixels[i + 1]);
      raw.addByte(pixels[i + 2]);
      raw.addByte(pixels[i + 3]);
    }
  }
  final compressed = _zlibCompress(raw.toBytes());

  final out = BytesBuilder();
  // PNG signature
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  // IHDR
  final ihdr = ByteData(13);
  ihdr.setUint32(0, width);
  ihdr.setUint32(4, height);
  ihdr.setUint8(8, 8);   // bit depth
  ihdr.setUint8(9, 6);   // RGBA
  ihdr.setUint8(10, 0);  // compression
  ihdr.setUint8(11, 0);  // filter
  ihdr.setUint8(12, 0);  // interlace
  _writeChunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _writeChunk(out, 'IDAT', compressed);
  _writeChunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  final typeBytes = type.codeUnits;
  out.add(typeBytes);
  out.add(data);
  // CRC32 over type + data
  final crcData = Uint8List(4 + data.length);
  crcData.setRange(0, 4, typeBytes);
  crcData.setRange(4, crcData.length, data);
  final crc = ByteData(4)..setUint32(0, _crc32(crcData));
  out.add(crc.buffer.asUint8List());
}

int _readUint32(Uint8List b, int pos) =>
    (b[pos] << 24) | (b[pos+1] << 16) | (b[pos+2] << 8) | b[pos+3];

// ── Minimal zlib (deflate) using dart:io ZLibDecoder/Encoder ─────────────────
Uint8List _zlibDecompress(Uint8List data) =>
    Uint8List.fromList(ZLibDecoder().convert(data));

Uint8List _zlibCompress(Uint8List data) =>
    Uint8List.fromList(ZLibEncoder(level: 6).convert(data));

// CRC32 table
final _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    t[n] = c;
  }
  return t;
}();

int _crc32(Uint8List data) {
  var c = 0xFFFFFFFF;
  for (final b in data) c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  return c ^ 0xFFFFFFFF;
}

// ── Bilinear resize ───────────────────────────────────────────────────────────
Uint8List resizePixels(Uint8List src, int sw, int sh, int dw, int dh) {
  final dst = Uint8List(dw * dh * 4);
  for (var y = 0; y < dh; y++) {
    for (var x = 0; x < dw; x++) {
      final sx = x * (sw - 1) / (dw - 1);
      final sy = y * (sh - 1) / (dh - 1);
      final x0 = sx.floor().clamp(0, sw - 1);
      final y0 = sy.floor().clamp(0, sh - 1);
      final x1 = (x0 + 1).clamp(0, sw - 1);
      final y1 = (y0 + 1).clamp(0, sh - 1);
      final fx = sx - x0, fy = sy - y0;
      final di = (y * dw + x) * 4;
      for (var c = 0; c < 4; c++) {
        final tl = src[(y0 * sw + x0) * 4 + c];
        final tr = src[(y0 * sw + x1) * 4 + c];
        final bl = src[(y1 * sw + x0) * 4 + c];
        final br = src[(y1 * sw + x1) * 4 + c];
        dst[di + c] = (tl * (1-fx) * (1-fy) + tr * fx * (1-fy) +
                       bl * (1-fx) * fy     + br * fx * fy).round().clamp(0, 255);
      }
    }
  }
  return dst;
}

// ── Main ──────────────────────────────────────────────────────────────────────
void main() async {
  const inputPath  = 'assets/images/spark_logo.png';
  const outputPath = 'assets/images/spark_logo_padded.png';

  final inputBytes = await File(inputPath).readAsBytes();
  final (srcW, srcH, srcPixels) = decodePng(inputBytes);
  print('Source: ${srcW}×${srcH}');

  // Android adaptive icon: 108dp canvas, safe zone = center 72dp (66.7%)
  // We target the logo at 56% of canvas → well inside safe zone on all shapes
  const canvasSize = 1024;
  final maxLogoSize = (canvasSize * 0.56).round(); // 573px

  // Scale logo to fit within maxLogoSize × maxLogoSize, preserving aspect ratio
  final scale = maxLogoSize / math.max(srcW, srcH);
  final dstW  = (srcW * scale).round();
  final dstH  = (srcH * scale).round();

  print('Logo resized to: ${dstW}×${dstH} on ${canvasSize}×${canvasSize} canvas');

  // Resize logo pixels
  final resized = resizePixels(srcPixels, srcW, srcH, dstW, dstH);

  // Create transparent canvas
  final canvas = Uint8List(canvasSize * canvasSize * 4); // all zeros = transparent

  // Composite logo centered
  final offX = (canvasSize - dstW) ~/ 2;
  final offY = (canvasSize - dstH) ~/ 2;
  for (var y = 0; y < dstH; y++) {
    for (var x = 0; x < dstW; x++) {
      final si = (y * dstW + x) * 4;
      final di = ((offY + y) * canvasSize + (offX + x)) * 4;
      canvas[di]     = resized[si];
      canvas[di + 1] = resized[si + 1];
      canvas[di + 2] = resized[si + 2];
      canvas[di + 3] = resized[si + 3];
    }
  }

  final outBytes = encodePng(canvasSize, canvasSize, canvas);
  await File(outputPath).writeAsBytes(outBytes);
  print('✓ Written: $outputPath');
}
