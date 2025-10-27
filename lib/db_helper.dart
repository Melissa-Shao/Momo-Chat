import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // database name
  static const String _dbName = "momo_ai.db";

  // table name
  static const String messageTable = "messages";
  static const String moodTable = "mood_logs";

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $messageTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          sender TEXT,
          text TEXT,
          timestamp TEXT
          )
          ''');
        await db.execute('''
          CREATE TABLE mood_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          mood TEXT,
          note TEXT,
          timestamp TEXT
          )
          ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
        CREATE TABLE mood_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mood TEXT,
          note TEXT,
          timestamp TEXT
        )
      ''');
        }
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

  // Insert mood log
  static Future<int> insertMood(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(moodTable, data);
  }

  // Query all the mood logs
  static Future<List<Map<String, dynamic>>> getAllMoods() async {
    final db = await database;
    return await db.query(moodTable, orderBy: "id DESC");
  }

  // Clean the mood_log table
  static Future<void> clearMoods() async {
    final db = await database;
    await db.delete(moodTable);
  }
}
