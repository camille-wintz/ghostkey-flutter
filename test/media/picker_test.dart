import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/media/folder_filter.dart';
import 'package:ghostkey/media/photo.dart';
import 'package:ghostkey/media/picker_selection.dart';
import 'package:ghostkey/server/dto/media.dart';
import 'package:ghostkey/veil/gallery_order.dart';

MediaItem _pic(String id, {String? folderId, String kind = 'image'}) =>
    MediaItem(id: id, kind: kind, title: id, body: '', bodyChars: 0, origin: 'author', folderId: folderId);

void main() {
  group('a single picker', () {
    test('hands back the first tap', () {
      final s = PickerSelection(multi: false);
      expect(s.tap(_pic('a'))?.map((i) => i.id), ['a']);
    });

    test('ignores a tap on a marked picture', () {
      final s = PickerSelection(multi: false, marked: {'a'});
      expect(s.tap(_pic('a')), isNull);
      expect(s.isMarked('a'), isTrue);
      expect(s.commitLabel, isNull);
    });

    test('a landed picture becomes the pick, without handing back', () {
      final s = PickerSelection(multi: false)
        ..land(_pic('a'))
        ..land(_pic('b'));
      expect(s.picked.map((i) => i.id), ['b']);
      expect(s.commitLabel, 'Use this');
    });
  });

  group('a multi picker', () {
    test('toggles, keeps the pick order, and never hands back on a tap', () {
      final s = PickerSelection(multi: true);
      expect(s.tap(_pic('a')), isNull);
      expect(s.tap(_pic('b')), isNull);
      expect(s.tap(_pic('c')), isNull);
      expect(s.tap(_pic('b')), isNull);
      expect(s.picked.map((i) => i.id), ['a', 'c']);
      expect(s.commitLabel, 'Add 2');
    });

    test('a marked picture is neither toggled nor landed', () {
      final s = PickerSelection(multi: true, marked: {'a'});
      s.tap(_pic('a'));
      s.land(_pic('a'));
      expect(s.picked, isEmpty);
      expect(s.commitLabel, isNull);
    });

    test('a landed picture joins the pick once', () {
      final s = PickerSelection(multi: true)
        ..tap(_pic('a'))
        ..land(_pic('b'))
        ..land(_pic('b'));
      expect(s.picked.map((i) => i.id), ['a', 'b']);
    });

    test('a removed picture leaves the pick', () {
      final s = PickerSelection(multi: true)
        ..tap(_pic('a'))
        ..forget('a');
      expect(s.picked, isEmpty);
    });
  });

  group('folders', () {
    final library = MediaLibrary(
      items: [_pic('a'), _pic('b', folderId: 'f1'), _pic('t', kind: 'text'), _pic('c', folderId: 'f2')],
      folders: const [
        MediaFolder(id: 'f2', name: 'b-side', sortIndex: 1),
        MediaFolder(id: 'f1', name: 'Places', sortIndex: 0),
        MediaFolder(id: 'f3', name: 'a-side', sortIndex: 1),
      ],
    );

    test('the grid shows pictures only, in the open part', () {
      expect(picturesIn(library, FolderFilter.all).map((i) => i.id), ['a', 'b', 'c']);
      expect(picturesIn(library, FolderFilter.unfiled).map((i) => i.id), ['a']);
      expect(picturesIn(library, const InFolder('f1')).map((i) => i.id), ['b']);
    });

    test('a picture lands in the open folder, and nowhere from All or Unfiled', () {
      expect(const InFolder('f1').landingFolderId, 'f1');
      expect(FolderFilter.all.landingFolderId, isNull);
      expect(FolderFilter.unfiled.landingFolderId, isNull);
    });

    test('a remembered filter comes back, and a deleted folder is All', () {
      for (final f in [FolderFilter.all, FolderFilter.unfiled, const InFolder('f1')]) {
        expect(FolderFilter.fromWire(f.wire, folders: library.folders), f);
      }
      expect(FolderFilter.fromWire('folder:gone', folders: library.folders), FolderFilter.all);
      expect(FolderFilter.fromWire(null), FolderFilter.all);
    });

    test('chips list folders by the author\'s order, then by name', () {
      expect(foldersInOrder(library.folders).map((f) => f.id), ['f1', 'f3', 'f2']);
    });
  });

  group('photos', () {
    Uint8List bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(16, 0)]);
    Uint8List ftyp(String brand) => Uint8List.fromList([0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0]);

    test('a re-encoded HEIC is named for what it is', () {
      expect(uploadFilename('IMG_1234.HEIC', bytes([0xFF, 0xD8, 0xFF, 0xE0])), 'IMG_1234.jpg');
      expect(uploadFilename('shot.png', bytes([0x89, 0x50, 0x4E, 0x47])), 'shot.png');
      expect(uploadFilename('', bytes([0xFF, 0xD8, 0xFF])), 'photo.jpg');
    });

    test('unknown bytes keep the picker\'s name', () {
      expect(uploadFilename('scan.tiff', bytes([1, 2, 3, 4])), 'scan.tiff');
    });

    test('HEIC is recognised by its brand, not its name', () {
      expect(isHeic(ftyp('heic')), isTrue);
      expect(isHeic(ftyp('mif1')), isTrue);
      expect(isHeic(ftyp('isom')), isFalse);
      expect(isHeic(bytes([0xFF, 0xD8, 0xFF])), isFalse);
    });
  });

  group('the gallery order', () {
    test('moves one picture to where it was dropped', () {
      expect(movedOrder(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
      expect(movedOrder(['a', 'b', 'c', 'd'], 3, 0), ['d', 'a', 'b', 'c']);
    });

    test('an impossible move changes nothing', () {
      expect(movedOrder(['a', 'b'], 0, 5), ['a', 'b']);
      expect(movedOrder(['a', 'b'], 1, 1), ['a', 'b']);
    });
  });
}
