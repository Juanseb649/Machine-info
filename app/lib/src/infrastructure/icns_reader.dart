import 'dart:typed_data';

class IcnsReader {
  const IcnsReader();

  static const _preferred = ['ic07', 'ic13', 'ic08', 'ic12', 'ic14', 'ic09', 'ic10', 'ic11'];
  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  Uint8List? extractPng(Uint8List bytes) {
    if (bytes.length < 8 || String.fromCharCodes(bytes.sublist(0, 4)) != 'icns') return null;
    final data = ByteData.sublistView(bytes);
    final total = data.getUint32(4).clamp(8, bytes.length);
    final found = <String, Uint8List>{};
    var offset = 8;
    while (offset + 8 <= total) {
      final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final length = data.getUint32(offset + 4);
      if (length < 8 || offset + length > total) break;
      final payload = Uint8List.sublistView(bytes, offset + 8, offset + length);
      if (_isPng(payload)) found[type] = payload;
      offset += length;
    }
    for (final type in _preferred) {
      final png = found[type];
      if (png != null) return png;
    }
    return found.isEmpty ? null : found.values.first;
  }

  bool _isPng(Uint8List payload) {
    if (payload.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (payload[i] != _pngSignature[i]) return false;
    }
    return true;
  }
}
