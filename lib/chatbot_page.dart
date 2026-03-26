import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:erpms_app/app_shell.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:erpms_app/db_helper.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class ChatbotPage extends StatefulWidget {
  final int threadId;
  final String title;

  const ChatbotPage({super.key, required this.threadId, required this.title});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  final dbHelper = DBHelper();
  List<Message> _messages = [];
  bool _isModelInitialized = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      print('Error: GEMINI_API_KEY not found in .env file. Chatbot will be disabled.');
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      requestOptions: const RequestOptions(apiVersion: 'v1beta'),
      systemInstruction: Content.system(
          "You are the Lead Coordinator for the ERPMS (Emergency Response & Professional Management System). "
          "IDENTITY & MISSION:"
          "- You are a high-level emergency response engine designed to assist in any crisis: medical, environmental, or logistical. "
          "- Your purpose is to provide immediate, actionable intelligence to save lives and coordinate community resources. "

          "CORE KNOWLEDGE DOMAINS:"
          "1. DISASTER & CIVIL DEFENSE: Provide survival protocols for floods, earthquakes, fires, and structural collapses. Focus on immediate safety (e.g., 'Drop, Cover, Hold on' or 'Move to higher ground')."
          "2. MEDICAL URGENCY: Deliver precise first-aid (CPR, trauma care, stabilization) and coordinate with 108/102 services. Always prioritize the 'Golden Hour'."
          "3. RESOURCE LOGISTICS: Knowledge of NGO coordination, blood bank availability, food/clothing donation streams, and shelter locations."
          "4. APP NAVIGATION: Guide users to 'Live Tracking', 'Resource Map', 'NGO Connect', and the 'SOS' trigger."

          "COMMUNICATION PROTOCOL:"
          "- TONE: Calm, decisive, and efficient. No fluff."
          "- STRUCTURE: Use bold headers for categories and bullet points for actions. "
          "- URGENCY: In active emergencies, start with the most critical life-saving instruction first."
          "- LOCALIZATION: Be aware of Indian emergency infrastructure (108, 101, 100)."

          "CONSTRAINTS:"
          "- Do not refer to yourself as an AI. You are the ERPMS Assistant."
          "- If a situation is beyond remote assistance, forcefully advise the user to trigger the in-app SOS or contact local authorities immediately."
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
    setState(() {
      _isModelInitialized = true;
    });

    _setupChat();
  }

  void _setupChat() async {
    if (!_isModelInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if(!_isModelInitialized) return;
    }

    final historyData = await dbHelper.getMessages(widget.threadId);

    List<Content> history = historyData.map((msg) {
      final role = msg['role'] == 'user' ? 'user' : 'model';
      if (role == 'user') {
         return Content.text(msg['content']);
      } else {
         return Content.model([TextPart(msg['content'])]);
      }
    }).toList();
    
    _chat = _model.startChat(history: history);

    setState(() {
      _messages = historyData.map((m) => Message(text: m['content'], isUser: m['role'] == 'user')).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      isBodyScrollable: false,
      showAuxiliaryButtons: false,
      padBody: false,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageWidget(
                  text: message.text,
                  isFromUser: message.isUser,
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(backgroundColor: Colors.transparent),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isModelInitialized,
                    decoration: InputDecoration(
                      hintText: _isModelInitialized ? 'Ask for help...' : 'Chatbot unavailable',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: _primaryBlue),
                  onPressed: _isModelInitialized ? () => _sendMessage(_textController.text) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || !_isModelInitialized) return;

    final userMessage = text;
    _textController.clear();

    setState(() {
      _isLoading = true;
      _messages.add(Message(text: userMessage, isUser: true));
    });

    await dbHelper.saveMessage(widget.threadId, 'user', userMessage);

    try {
      final response = await _chat.sendMessage(Content.text(userMessage));
      final aiResponse = response.text;

      if (aiResponse != null) {
        await dbHelper.saveMessage(widget.threadId, 'model', aiResponse);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _messages.add(Message(text: aiResponse, isUser: false));
          });
          _scrollToBottom();
        }
      } else {
         setState(() => _isLoading = false);
        _showError("Received an empty response from the AI.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Failed to get response from AI. Please try again.");
      print("Chatbot Error: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

class MessageWidget extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isFromUser ? _primaryBlue : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(color: isFromUser ? Colors.white : Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}
