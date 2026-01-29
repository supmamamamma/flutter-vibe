import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast_web/sembast_web.dart';

/// App-level database for Web (IndexedDB) via sembast_web.
///
/// NOTE: sembast_web stores data in the browser's IndexedDB.
final appDatabaseProvider = Provider<Future<Database>>((ref) async {
  // One database per app.
  return databaseFactoryWeb.openDatabase('ai_chat_pwa.db');
});

