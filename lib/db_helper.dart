import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // database name
  static const String _dbName = "momo_ai.db";

  // table name
  static const String messageTable = "messages";

  // Get the database
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // Init database
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // sender TEXT: sender is the column name, TEXT is the data type: string or datetime
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $messageTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          sender TEXT,
          text TEXT,
          timestamp TEXT
          )
          ''');
      },
    );
  }

  // Insert message
  static Future<int> insertMessage(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(messageTable, data);
  }

  // Query all the messages
  static Future<List<Map<String, dynamic>>> getAllMessages() async {
    final db = await database;
    return await db.query(messageTable, orderBy: "id ASC");
  }

  // Clean the message table
  static Future<void> clearMessages() async {
    final db = await database;
    await db.delete(messageTable);
  }
}
