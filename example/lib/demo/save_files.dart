// Exports: a save dialog on a computer, the share sheet on a phone or the
// web. A computer's share sheet has no "Save", so files go to a place the
// user picks there.
import 'package:file_selector/file_selector.dart'
    show getDirectoryPath, getSaveLocation;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// macOS, Windows and Linux: a save dialog instead of the share sheet.
bool get savesToDisk =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Saves [files] under [names] where the user picks, or shares them.
/// Returns where they went ("flutter_zxing_labels.pdf", "12 files in
/// Labels"), or `null` when the dialog or the sheet was dismissed.
Future<String?> saveOrShare(
  BuildContext context,
  List<XFile> files,
  List<String> names,
) async {
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
