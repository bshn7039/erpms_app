import 'package:erpms_app/chatbot_page.dart';
import 'package:flutter/material.dart';

import 'package:erpms_app/db_helper.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final dbHelper = DBHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ERPMS Assistant")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.db.then((db) => db.query("threads", orderBy: "id DESC")),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final thread = snapshot.data![index];
              return ListTile(
                title: Text(thread['title']),
                subtitle: Text(thread['timestamp'].split('T')[0]),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ChatbotPage(threadId: thread['id'], title: thread['title']),
                )),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Conversation'),
                        content: const Text('Are you sure you want to delete this conversation?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await dbHelper.deleteThread(thread['id']);
                      setState(() {});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // Logic: Create a new thread ID first, then go to the chat page
          int id = await dbHelper.createThread("New Consultation");
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ChatbotPage(threadId: id, title: "New Consultation"),
          ));
        },
      ),
    );
  }
}
