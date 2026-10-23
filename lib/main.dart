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
  String modelName = '';

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
    setState(() {
      apiKey = key;
      modelName = '';
    });
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _pickModel() async {
    if (modelName.isNotEmpty) return modelName;
    try {
      final res = await http.get(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final models = (data['models'] as List?) ?? [];
        for (final m in models) {
          final name = (m['name'] ?? '').toString();
          final methods =
              (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
          if (name.contains('flash') &&
              (methods.isEmpty ||
                  methods.contains('generateContent'))) {
            modelName = name.replaceFirst('models/', '');
            return modelName;
          }
        }
      }
    } catch (_) {}
    modelName = 'gemini-2.0-flash';
    return modelName;
  }

  Future<void> _askGemini(String userText) async {
    if (apiKey.isEmpty) {
      _addBot('⚠️ خاصك تحط مفتاح Gemini! كليك على ⚙️ فوق.');
      return;
    }
    setState(() => loading = true);
    try {
      final model = await _pickModel();
      final learnedText = learned.isEmpty ? 'لا شيء' : learned.join('\n');
      final system = 'أنت "مستعكِل"، مساعد شخصي ذكي داخل تطبيق أندرويد. '
          'المستخدم يتحدث معك بالدارجة المغربية أو العربية أو الفرنسية.\n\n'
          'المعلومات التي تعلمتها من المستخدم سابقاً:\n$learnedText\n\n'
          'قواعد:\n'
          '1. أجب دائماً بلغة المستخدم وبأسلوب بسيط وودود.\n'
          '2. إذا طلب البحث في الإنترنت، اكتب في نهاية ردك: [SEARCH: كلمات البحث]\n'
          '3. إذا طلب حفظ معلومة، اكتب: [SAVE: المعلومة]\n'
          '4. إذا علّمك معلومة جديدة، اكتب: [LEARN: المعلومة] وأكد أنك تعلمتها.\n'
          '5. لا تكتب هذه الرموز إلا عند الحاجة فعلاً.';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': system}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userText}
              ]
            }
          ],
        }),
      );
      if (res.statusCode != 200) {
        modelName = '';
        _addBot('❌ خطأ من Gemini (code ${res.statusCode}). تأكد من المفتاح.');
        return;
      }
      final data = jsonDecode(res.body);
      String reply = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          'ما جاوبش.';
      final searchMatch = RegExp(r'\[SEARCH:\s*(.+?)\]').firstMatch(reply);
      final saveMatch = RegExp(r'\[SAVE:\s*(.+?)\]').firstMatch(reply);
      final learnMatch = RegExp(r'\[LEARN:\s*(.+?)\]').firstMatch(reply);
      reply =
          reply.replaceAll(RegExp(r'\[(SEARCH|SAVE|LEARN):.*?\]'), '').trim();
      if (searchMatch != null) {
        final q = searchMatch.group(1)!.trim();
        _addBot('$reply\n\n🔍 كنقلب على: $q');
        final gurl = Uri.parse(
            'https://www.google.com/search?q=${Uri.encodeComponent(q)}');
        if (await canLaunchUrl(gurl)) {
          launchUrl(gurl, mode: LaunchMode.externalApplication);
        }
      } else if (saveMatch != null) {
        final s = saveMatch.group(1)!.trim();
        learned.add('ملاحظة: $s');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('learned', learned);
        _addBot('$reply\n\n💾 تحفظات: $s');
      } else if (learnMatch != null) {
        final l = learnMatch.group(1)!.trim();
        learned.add(l);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('learned', learned);
        _addBot('$reply\n\n📚 تعلمت: $l');
      } else {
        _addBot(reply);
      }
    } catch (e) {
      _addBot('❌ خطأ فالاتصال: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void _send() {
    final text = controller.text.trim();
    if (text.isEmpty || loading) return;
    controller.clear();
    setState(() {
      messages.add(ChatMessage(text, true));
    });
    _scrollDown();
    _askGemini(text);
  }

  void _addBot(String text) {
    setState(() {
      messages.add(ChatMessage(text, false));
    });
    _scrollDown();
  }

  void _openSettings() {
    final keyController = TextEditingController(text: apiKey);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '⚙️ الإعدادات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _saveKey(keyController.text.trim());
                Navigator.pop(ctx);
                _addBot('✅ تسجل المفتاح!');
              },
              child: const Text('حفظ'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🤖 مستعكِل AI'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  return Align(
                    alignment:
                        m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: m.isUser
                            ? Colors.teal.shade700
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('كيفكر...'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'كلمني بأي لغة...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
