// Exports: a save dialog on a computer, a download on the web, the share
// sheet on a phone. A computer's share sheet has no "Save", so files go to
// a place the user picks there.
import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart'
    show getDirectoryPath, getSaveLocation;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// The web, macOS, Windows and Linux: a download or a save dialog
/// instead of the share sheet.
bool get savesToDisk =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Downloads [files] on the web (several in one ZIP named [zipName]),
/// saves them under [names] where the user picks on a computer, or shares
/// them. Returns where they went ("flutter_zxing_labels.pdf", "12 files
/// in Labels"), or `null` when the dialog or the sheet was dismissed.
Future<String?> saveOrShare(
  BuildContext context,
  List<XFile> files,
  List<String> names, {
  String zipName = 'flutter_zxing_files.zip',
}) async {
  if (kIsWeb) {
    final XFile download;
    final String name;
    if (files.length == 1) {
      download = XFile.fromData(
        await files.single.readAsBytes(),
        name: names.single,
        mimeType: files.single.mimeType,
      );
      name = names.single;
    } else {
      final Archive zip = Archive();
      for (int i = 0; i < files.length; i++) {
        zip.addFile(ArchiveFile.bytes(names[i], await files[i].readAsBytes()));
      }
      download = XFile.fromData(
        ZipEncoder().encodeBytes(zip),
        name: zipName,
        mimeType: 'application/zip',
      );
      name = zipName;
    }
    // A download: the browser saves it under the file's name.
    await download.saveTo(name);
    return name;
  }
  if (savesToDisk) {
    if (files.length == 1) {
      final location = await getSaveLocation(suggestedName: names.single);
      if (location == null) {
        return null;
      }
      await files.single.saveTo(location.path);
      return _last(location.path);
    }
    final String? dir = await getDirectoryPath(confirmButtonText: 'Save');
    if (dir == null) {
      return null;
    }
    for (int i = 0; i < files.length; i++) {
      await files[i].saveTo('$dir/${names[i]}');
    }
    return '${files.length} files in ${_last(dir)}';
  }
  // XFile.fromData has no path off the web: the names go separately.
  final RenderBox? box = context.mounted
      ? context.findRenderObject() as RenderBox?
      : null;
  final ShareResult shared = await SharePlus.instance.share(
    ShareParams(
      files: files,
      fileNameOverrides: names,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
  return shared.status == ShareResultStatus.dismissed ? null : '';
}

String _last(String path) =>
    path.split(RegExp(r'[/\\]')).lastWhere((String s) => s.isNotEmpty);
