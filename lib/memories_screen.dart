import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'db_helper.dart';
import 'dart:math';
import 'package:lottie/lottie.dart';

class MoodEntry {
  final int? id;
  final String mood; // happy, ok, sad...
  final String note;
  final String timestamp;

  MoodEntry({
    this.id,
    required this.mood,
    required this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'note': note,
      'timestamp': timestamp,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'],
      mood: map['mood'],
      note: map['note'] ?? "",
      timestamp: map['timestamp'],
    );
  }
}

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<MoodEntry> _moods = [];
  List<ChatMessage> _recentUserMessages = [];
  String _insightText = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future _loadData() async {
    // 1. All the mood_logs, order by time DESC
    final moodRows = await DBHelper.getAllMoods();
    final moodsParsed = moodRows.map((m) => MoodEntry.fromMap(m)).toList();
    // Remove duplicated mood in the same say
    final seenDays = <String>{};
    final uniqueMoods = <MoodEntry>[];
    for (final m in moodsParsed) {
      final day = m.timestamp.substring(0,10); // "YYYY-MM-DD"
      if  (seenDays.add(day)) {
        uniqueMoods.add(m);
      }
    }

    // 2. All the messages
    final msgRows = await DBHelper.getAllMessages();
    final allMessages = msgRows.map((m) => ChatMessage.fromMap(m)).toList();

    // 3. Filter only the lastest 20 user messages
    // Note: DBHelper.getAllMessages() is ordered by id ASC
    List<ChatMessage> userOnlyNewestFirst = allMessages
        .where((m) => m.sender == "user")
        .toList()
        .reversed
        .toList();
    final recent20 = userOnlyNewestFirst.take(20).toList();

    // 4. Generate insight using the lastest user messages
    final insight = _buildInsightFromMessages(recent20);
    final pickedForDisplay = _pickRandomMessages(recent20, 3);

    setState(() {
      _moods = uniqueMoods;
      _recentUserMessages = pickedForDisplay;
      _insightText = insight;
    });
  }

  List<ChatMessage> _pickRandomMessages(
      List<ChatMessage> source,
      int count,
      ) {
    if (source.isEmpty) return [];

    // if less than the count, just return
    if (source.length <= count) {
      return List<ChatMessage>.from(source);
    }

    // chose random count none duplicated message
    final rand = Random();
    final picked = <ChatMessage>[];
    final usedIndexes = <int>{};

    while (picked.length < count && usedIndexes.length < source.length) {
      final i = rand.nextInt(source.length); // 0 .. length-1
      if (!usedIndexes.contains(i)) {
        usedIndexes.add(i);
        picked.add(source[i]);
      }
    }

    return picked;
  }

  // This function is for generating the mood summary
  // The method is making a simple keyword detection
  String _buildInsightFromMessages(List<ChatMessage> msgs) {
    if (msgs.isEmpty) {
      return "Momo is still getting to know you 💜";
    }

    final fullText = msgs.map((m) => m.text).join(" ").toLowerCase();
    final feelsTired = fullText.contains("tired") ||
                       fullText.contains("exhausted") ||
                       fullText.contains("sleepy");
    final feelsStress = fullText.contains("stress");
    final hasInterview = fullText.contains("interview");

    List<String> bullets = [];
    if (feelsTired) {
      bullets.add("You've been saying you feel tired lately. Momo really cares about you — remember to rest, okay?");
    }
    if (feelsStress) {
      bullets.add("You’ve mentioned feeling stressed. Momo is always here to support you 💜");
    }
    if (hasInterview) {
      bullets.add("You talked about an interview or something important coming up. Momo wishes you the best of luck 📅");
    }
    if (bullets.isEmpty) {
      bullets.add("Momo has been listening to you carefully ✨");
    }

    return bullets.join("\n");
  }

  // This function is called when user click the 🙂😐☹️ emoji: write the mood into DB and update the UI
  Future<void> _addMood(String moodTag) async {
    final now = DateTime.now().toIso8601String();
    final entry = MoodEntry(
        mood: moodTag,
        note: "",
        timestamp: now
    );

    await DBHelper.insertMood(entry.toMap());
    debugPrint("Inserted mood: $moodTag at $now");
    await _loadData();
  }

  // ----- UI helpers -----
  Widget _moodButton(String tag, String emoji, Color color) {
    String lottiePath;
    switch(tag) {
      case "happy":
        lottiePath = "assets/lottie/Great.json";
        break;
      case "ok":
        lottiePath = "assets/lottie/Okay.json";
        break;
      default:
        lottiePath = "assets/lottie/Bad.json";
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.10),
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onPressed: () => _addMood(tag),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            lottiePath,
            width: 60,
            height: 60,
            repeat: true,
          ),
          Text(
            tag,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _moodButton("happy", "🙂", Colors.green),
        _moodButton("ok", "😐", Colors.amber),
        _moodButton("sad", "☹️", Colors.redAccent),
      ],
    );
  }

  // Recent mood logs (most 5)
  Widget _buildRecentMoodList() {
    if (_moods.isEmpty) {
      return const Text(
        "No mood entries yet.\nTap a mood above to log today 💜",
        style: TextStyle(fontSize: 14, color: Colors.black54),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
        _moods.take(5).map((m) {
          final day = m.timestamp.substring(0, 10);

          String lottiePath = m.mood == "happy"
              ? "assets/lottie/Great.json"
              : m.mood == "ok"
              ? "assets/lottie/Okay.json"
              : "assets/lottie/Bad.json";

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day,
                style: const TextStyle( fontWeight: FontWeight.w500, fontSize: 14)),
                Row(
                  children: [
                    Lottie.asset(
                      lottiePath,
                      width: 40,
                      height: 40,
                      repeat: true,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.mood,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
    );
  }

  // Recent user's message (most 3)
  Widget _buildRecentMessagesPreview() {
    if (_recentUserMessages.isEmpty) {
      return const Text(
        "You haven't chatted with Momo yet.\nGo tell her how you're feeling 💬",
        style: TextStyle(fontSize: 14, color: Colors.black54),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _recentUserMessages.map((msg) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  // mood summary card
  Widget _buildInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Text(
        _insightText,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Memories",
                style: TextStyle( fontSize: 22, fontWeight: FontWeight.w600,),
              ),
              const SizedBox(height: 4,),
              Text(
                "What Momo remembers about you 💜",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600,),
              ),
              const SizedBox(height: 24),

              //Insights
              const Text(
                "Emotional Insights",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,),
              ),
              const SizedBox(height: 8),
              _buildInsightsCard(),
              const SizedBox(height: 24),

              // Mood logger
              const Text(
                "How do you feel today?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,),
              ),
              const SizedBox(height: 8),
              _buildMoodButtons(),
              const SizedBox(height: 16),
              _buildRecentMoodList(),
              const SizedBox(height: 24),

              // Recent messages
              const Text(
                "Recently you said...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,),
              ),
              const SizedBox(height: 8),
              _buildRecentMessagesPreview(),
            ],
          ),
        ),
    );
  }
}
