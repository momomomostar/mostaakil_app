import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MostaakilApp());

class MostaakilApp extends StatelessWidget {
  const MostaakilApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مستعكِل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ChatMessage> messages = [];
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  String apiKey = '';
  bool loading = false;
  List<String> learned = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    messages.add(ChatMessage(
      'أهلاً! أنا مستعكِل بالذكاء الاصطناعي 🧠\n'
      'كلمني بأي طريقة: دارجة، عربية، فرنسية...\n\n'
      'مثلاً:\n'
      '• قول لي: قلب لي على أخبار المغرب\n'
      '• قول لي: احفظلي رقمي 0612345678\n'
      '• قول لي: علمني أن عاصمة المغرب هي الرباط\n\n'
      '⚠️ أول مرة: كليك على ⚙️ فوق وحط مفتاح Gemini ديالك.',
      false,
    ));
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      apiKey = prefs.getString('apiKey') ?? '';
      learned = prefs.getStringList('learned') ?? [];
    });
  }

  Future<void> _saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', key);
    setState(() => apiKey = key);
  }
  
