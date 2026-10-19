import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_slot_manager/import/jpeg_exif.dart';

/// 고른 파일의 이름(확장자 제외)과 바이트. 고르지 않으면 null.
typedef PickedFile = ({String name, Uint8List bytes});

const _jpeg = XTypeGroup(
  label: 'JPEG',
  extensions: ['jpg', 'jpeg'],
  mimeTypes: ['image/jpeg'],
  uniformTypeIdentifiers: ['public.jpeg'],
);

const _images = XTypeGroup(
  label: '이미지',
  extensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
  mimeTypes: ['image/*'],
  uniformTypeIdentifiers: ['public.image'],
);

/// JPEG 하나를 골라 앞부분만 읽는다.
Future<PickedFile?> pickJpegHead() async {
  final file = await openFile(acceptedTypeGroups: [_jpeg]);
  if (file == null) return null;
  final chunks = await file.openRead(0, jpegHeadBytes).toList();
  return (
    name: p.basenameWithoutExtension(file.name),
    bytes: Uint8List.fromList([for (final chunk in chunks) ...chunk]),
  );
}

/// 이미지 하나를 골라 전부 읽는다.
Future<PickedFile?> pickImage() async {
  final file = await openFile(acceptedTypeGroups: [_images]);
  if (file == null) return null;
  return (
    name: p.basenameWithoutExtension(file.name),
    bytes: await file.readAsBytes(),
  );
}

const _raf = XTypeGroup(
  label: 'RAF',
  extensions: ['raf'],
  mimeTypes: ['image/x-fuji-raf', 'application/octet-stream'],
  uniformTypeIdentifiers: ['com.fuji.raw-image'],
);

/// 후지 RAW(RAF) 하나를 골라 전부 읽는다.
Future<PickedFile?> pickRaf() async {
  final file = await openFile(acceptedTypeGroups: [_raf]);
  if (file == null) return null;
  return (
    name: p.basenameWithoutExtension(file.name),
    bytes: await file.readAsBytes(),
  );
}
