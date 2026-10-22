import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MostaakilApp());
}

class MostaakilApp extends StatelessWidget {
  const MostaakilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مستعكِل',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
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
  List<String> learned = [];

  @override
  void initState() {
    super.initState();
    _loadLearned();
    messages.add(ChatMessage(
      'أهلاً! أنا "مستعكِل"، مساعدك الشخصي.\n'
      'الأوامر اللي كنفهمها دابا:\n'
      '🔍 ابحث عن ... → كنقلب لك فالإنترنت\n'
      '💾 احفظ: ... → كنحفظ المعلومة\n'
      '📚 علمني: سؤال = جواب → كنتعلم منك\n'
      '🧠 ماذا تعلمت → كنوريك شنو تعلمت\n'
      '🗑️ امسح التعلم → كنمسح كلشي',
      false,
    ));
  }

  Future<void> _loadLearned() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      learned = prefs.getStringList('learned') ?? [];
    });
  }

  Future<void> _saveLearned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('learned', learned);
  }

  void _send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    setState(() {
      messages.add(ChatMessage(text, true));
    });

    final lower = text;
    String reply;

    if (lower.startsWith('ابحث عن') ||
        lower.startsWith('قلب على') ||
        lower.startsWith('ابحث')) {
      String query =
          text.replaceFirst(RegExp(r'^(ابحث عن|قلب على|ابحث)'), '').trim();
      if (query.isNotEmpty) {
        reply = 'كنقلب لك على: $query ...';
        _addBot(reply);
        final url = Uri.parse(
            'https://www.google.com/search?q=${Uri.encodeComponent(query)}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
        return;
      }
    } else if (lower.startsWith('احفظ')) {
      String note =
          text.replaceFirst('احفظ', '').replaceFirst(':', '').trim();
      if (note.isNotEmpty) {
        learned.add('ملاحظة: $note');
        await _saveLearned();
        reply = '✅ تحفظات المعلومة: $note';
        _addBot(reply);
        return;
      }
    } else if (lower.startsWith('علمني')) {
      String lesson =
          text.replaceFirst('علمني', '').replaceFirst(':', '').trim();
      if (lesson.contains('=')) {
        learned.add(lesson);
        await _saveLearned();
        reply =
            '📚 تعلمت! منين تسولني على "$lesson" غادي نفتكر.';
        _addBot(reply);
        return;
      }
    } else if (lower.contains('ماذا تعلمت') ||
        lower.contains('شنو تعلمت')) {
      if (learned.isEmpty) {
        reply = '🤷 لسا ما تعلمت والو. علمني بصيغة: علمني: سؤال = جواب';
      } else {
        reply = '🧠 هادو حوايج اللي تعلمتهم:\n' +
            learned.map((e) => '• $e').join('\n');
      }
      _addBot(reply);
      return;
    } else if (lower.contains('امسح التعلم')) {
      learned.clear();
      await _saveLearned();
      _addBot('🗑️ تمسح كلشي.');
      return;
    }

    reply = '🤔 مافهمتش هاد الأمر مزيان. جرب:\n'
        '• ابحث عن (حاجة)\n'
        '• احفظ: (معلومة)\n'
        '• علمني: (سؤال = جواب)\n'
        '• ماذا تعلمت';
    _addBot(reply);
  }

  void _addBot(String text) {
    setState(() {
      messages.add(ChatMessage(text, false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🤖 مستعكِل'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  return Align(
                    alignment: m.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'كتب الأمر هنا...',
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
