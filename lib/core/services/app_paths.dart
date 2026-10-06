import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folder that holds the database and settings.
///
/// Linux and Windows keep it under Documents, where existing installs already
/// have their data. macOS guards Documents behind a permission prompt, so there
/// it is the app's own folder in ~/Library/Application Support.
Future<Directory> appDataDirectory() async {
  if (Platform.isMacOS) {
    return getApplicationSupportDirectory();
  }
  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, 'tomsllama'));
}
