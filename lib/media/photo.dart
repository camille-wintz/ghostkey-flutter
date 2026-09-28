import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

// A photo from the camera or the phone's library, ready for the library's
// upload. The server takes png/jpg/webp/gif and refuses HEIC, which is what
// iPhones (and some Android phones) shoot: `image_picker` re-encodes to JPEG
// whenever it is asked for a quality, so every pick here asks for one — and
// the longest edge is held to 3000px, since a 12 MP photo is megabytes over
// a phone's uplink for pixels no screen here draws.

enum PhotoSource { camera, photos }

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

/// A photo that is still HEIC after the picker had its go — a picker that
/// handed the original back. Said rather than sent, since the server's 415
/// would say less.
class PhotoUnreadable implements Exception {
  const PhotoUnreadable();

  static const String message = "That photo couldn't be read. Try exporting it as a JPEG.";

  @override
  String toString() => message;
}

/// Null when the author backed out of the camera or the photo library.
Future<PickedPhoto?> pickPhoto(PhotoSource source) async {
  final file = await ImagePicker().pickImage(
    source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 88,
    maxWidth: 3000,
    maxHeight: 3000,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (isHeic(bytes)) throw const PhotoUnreadable();
  return PickedPhoto(bytes: bytes, filename: uploadFilename(file.name, bytes));
}

/// The name to upload [bytes] under: the picker's own, with the extension
/// the bytes really are. A re-encoded `IMG_1234.HEIC` is a JPEG with a HEIC
/// name, and the server reads the extension when the mime says less.
String uploadFilename(String name, Uint8List bytes) {
  final ext = _extensionOf(bytes);
  final base = name.trim().isEmpty ? 'photo' : name.trim();
  if (ext == null) return base;
  final dot = base.lastIndexOf('.');
  final stem = dot <= 0 ? base : base.substring(0, dot);
  return '$stem.$ext';
}

String? _extensionOf(Uint8List b) {
  bool at(int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (at(0, const [0x47, 0x49, 0x46, 0x38])) return 'gif';
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) && at(8, const [0x57, 0x45, 0x42, 0x50])) return 'webp';
  return null;
}

const _heicBrands = {'heic', 'heix', 'heim', 'heis', 'hevc', 'hevx', 'mif1', 'msf1'};

/// An ISO box file whose `ftyp` brand is one of HEIF's. `mif1` is also
/// AVIF's generic brand, but a picker hands back no AVIF.
bool isHeic(Uint8List b) {
  if (b.length < 12) return false;
  if (String.fromCharCodes(b.sublist(4, 8)) != 'ftyp') return false;
  return _heicBrands.contains(String.fromCharCodes(b.sublist(8, 12)));
}
