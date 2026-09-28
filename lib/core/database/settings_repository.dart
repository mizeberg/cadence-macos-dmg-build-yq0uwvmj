import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SettingsRepository {
  const SettingsRepository(this.database);

  final DatabaseExecutor database;

  Future<String?> getString(String key) async {
    final rows = await database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String?;
  }

  Future<void> putString(String key, String value) async {
    await database.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String key) =>
      database.delete('settings', where: 'key = ?', whereArgs: [key]);
}
