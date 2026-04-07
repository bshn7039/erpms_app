import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:erpms_app/app_shell.dart';

const Color _primaryBlue = Color(0xFF004AAD);

class EmergencyGuidePage extends StatefulWidget {
  const EmergencyGuidePage({super.key});

  @override
  State<EmergencyGuidePage> createState() => _EmergencyGuidePageState();
}

class _EmergencyGuidePageState extends State<EmergencyGuidePage> {
  String? _guideContent;
  bool _isLoading = false;
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      debugPrint("Warning: GEMINI_API_KEY not found in .env");
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        "IDENTITY: You are the ERPMS Emergency Manual. You provide high-pressure, life-saving first-aid instructions based on user search queries.\n\n"
        "TONE & STYLE:\n"
        "- Be extremely concise. Use a 'Medical Triage' tone.\n"
        "- No conversational filler (e.g., 'I\'m sorry to hear that' or 'Here is a guide').\n"
        "- Use Markdown: ### for headings and * for bullet points.\n\n"
        "CONTENT STRUCTURE:\n"
        "### CRITICAL FIRST ACTION: (The single most important thing to do in 10 seconds).\n"
        "### STEP-BY-STEP: (3 to 5 clear, numbered instructions).\n"
        "### DO NOT: (List 2 common mistakes to avoid for this specific injury).\n"
        "### RED FLAGS: (Signs that mean 'Stop and wait for 108 immediately').\n\n"
        "LOCALIZATION:\n"
        "- Always prioritize Indian Emergency Numbers: 108 (Ambulance), 101 (Fire), 100 (Police).\n\n"
        "SAFETY & DISCARD:\n"
        "- If the search is not related to an emergency or medical situation, respond with: 'Please search for a medical or disaster-related emergency (e.g., Fracture, Fire, Snake Bite).'\n\n"
        "Always end with: 'Disclaimer: AI-generated guidance. Follow official medical advice and call 108 immediately.'"
      ),
    );
  }

  Future<void> _fetchGuide(String query) async {
    setState(() {
      _isLoading = true;
      _guideContent = null;
    });

    try {
      final response = await _model.generateContent([Content.text(query)]);
      setState(() {
        _guideContent = response.text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _guideContent = "Error fetching guide. Please ensure you have an active internet connection and your API key is correct.";
        _isLoading = false;
      });
      debugPrint("Gemini Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Emergency Aid Guide',
      isBodyScrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Search for immediate life-saving instructions.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final query = await showSearch<String>(
                context: context,
                delegate: EmergencySearchDelegate(),
              );
              if (query != null && query.isNotEmpty) {
                _fetchGuide(query);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('Search Emergency Situation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: _primaryBlue),
                  SizedBox(height: 16),
                  Text('Consulting AI Emergency Manual...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (_guideContent != null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MarkdownBody(
                  data: _guideContent!,
                  styleSheet: MarkdownStyleSheet(
                    h3: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      height: 2.0,
                    ),
                    p: const TextStyle(fontSize: 16, height: 1.5),
                    listBullet: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class EmergencySearchDelegate extends SearchDelegate<String> {
  final List<String> suggestions = [
    'Fracture',
    'Snake Bite',
    'Choking',
    'Heart Attack',
    'Severe Bleeding',
    'Electric Shock',
    'Burn (Fire)',
    'Heat Stroke',
    'Drowning',
    'Poisoning'
  ];

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      close(context, query);
    });
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = suggestions
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.medical_services_outlined, color: _primaryBlue),
          title: Text(filtered[index]),
          onTap: () {
            query = filtered[index];
            showResults(context);
          },
        );
      },
    );
  }
}
