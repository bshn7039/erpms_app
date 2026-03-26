
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    String path = join(await getDatabasesPath(), "erpms_chat.db");
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      // Table 1: To list all conversations
      await db.execute("CREATE TABLE threads (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, timestamp TEXT)");
      // Table 2: To store every message inside those conversations
      await db.execute("CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, thread_id INTEGER, role TEXT, content TEXT)");
    });
  }

  // CREATE: Start a new chat session
  Future<int> createThread(String title) async {
    final dbClient = await db;
    return await dbClient.insert("threads", {
      'title': title,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // SAVE: Store a message (either user or AI)
  Future<void> saveMessage(int threadId, String role, String content) async {
    final dbClient = await db;
    await dbClient.insert("messages", {
      'thread_id': threadId,
      'role': role,
      'content': content,
    });
  }

  // LOAD: Get all messages for one chat
  Future<List<Map<String, dynamic>>> getMessages(int threadId) async {
    final dbClient = await db;
    return await dbClient.query("messages", where: "thread_id = ?", whereArgs: [threadId]);
  }

  // DELETE: Delete a thread and all its messages
  Future<void> deleteThread(int threadId) async {
    final dbClient = await db;
    await dbClient.delete("messages", where: "thread_id = ?", whereArgs: [threadId]);
    await dbClient.delete("threads", where: "id = ?", whereArgs: [threadId]);
  }

  // METRICS: Count all messages stored locally
  Future<int> getTotalMessagesCount() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery("SELECT COUNT(*) AS count FROM messages");
    if (result.isEmpty) return 0;
    final value = result.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
