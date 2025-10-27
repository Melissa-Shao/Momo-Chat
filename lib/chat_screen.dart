import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final int? id;
  final String sender; // the user or the AI
  final String text;
  final String timestamp;

  ChatMessage({
    this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  // Convert to map for easy to store into DB
  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      sender: map['sender'],
      text: map['text'],
      timestamp: map['timestamp'],
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // chat message lists (right now store in memory)
  final List<ChatMessage> _messages = [];
  // TextField controller, use for getting the context from the input
  final TextEditingController _textController = TextEditingController();
  // scrollable control
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  // Load messages from DB
  Future<void> _loadMessages() async {
    final data = await DBHelper.getAllMessages();
    setState(() {
      _messages.clear();
      _messages.addAll(data.map((e) =>
          ChatMessage.fromMap(e)).toList()
      );
    });
    _scrollToBottomSoon();
  }

  // Save chat message to DB
  Future<void> _saveMessage(ChatMessage msg) async {
    await DBHelper.insertMessage(msg.toMap());
  }

  // Function call for user send message
  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 1. add this user message into _messages list
    final now = DateTime.now().toIso8601String();
    final userMsg = ChatMessage(sender: 'user', text: text, timestamp: now);

    setState(() {
      _messages.add(userMsg);
    });
    _saveMessage(userMsg);
    // clear the input field
    _textController.clear();
    // 2. call AI reply
    _callAIReply(text);
    // 3. scroll to the bottom
    _scrollToBottomSoon();
  }

  Future<void> _callAIReply(String userText) async {
    // 1. create system prompt
    final systemPrompt = "You are Momo, a supportive emotional companion. "
        "Reply in a friendly, encouraging, empathetic tone. "
        "Keep responses short (1-3 sentences). "
        "If the user sounds stressed or tired, acknowledge feelings first.";
    final combinedUserMessage =
        "User says: \"$userText\"\n"
        "Respond as Momo, in gentle supportive style.";

    // 2. Gemini API key
    const String geminiApiKey = "AIzaSyCarJ-e0zUW4qIdeED9V03HPBUAwWguQnE";

    // 3. Google Gemini endpoint
    final uri = Uri.parse(  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent?key=$geminiApiKey");
    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": systemPrompt},
                {"text": combinedUserMessage},
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Default value for the replyText if the api not works
        String replyText = "I'm here with you 💜";
        try {
          replyText = data["candidates"][0]["content"]["parts"][0]["text"];
        } catch(parseErr) {
          print("Parse AI reply error: $parseErr");
        }
        // Save to database and update UI
        final now = DateTime.now().toIso8601String();
        final aiMsg = ChatMessage(
            sender: "ai",
            text: replyText,
            timestamp: now
        );

        setState(() {
          _messages.add(aiMsg);
        });
        await _saveMessage(aiMsg);
        _scrollToBottomSoon();
      } else {
        final now = DateTime.now().toIso8601String();
        final fallbackMsg = ChatMessage(
          sender: "ai",
          text:
          "Momo tried to think but got server error ${response.statusCode}. "
              "Even if I'm confused, I'm staying with you 💜",
          timestamp: now,
        );

        setState(() {
          _messages.add(fallbackMsg);
        });
        await _saveMessage(fallbackMsg);
        _scrollToBottomSoon();
        print("Gemini API error ${response.statusCode}: ${response.body}");
      }
    } catch(e) {
      final now = DateTime.now().toIso8601String();
      final offlineMsg = ChatMessage(
        sender: "ai",
        text:
        "I can't reach my brain in the cloud right now, but I'm still here and I care about you 💜",
        timestamp: now,
      );

      setState(() {
        _messages.add(offlineMsg);
      });
      await _saveMessage(offlineMsg);
      _scrollToBottomSoon();
      print("Gemini API exception: $e");
    }
  }

  // Function call for simulating AI reply
  void _fakeAIReply(String userText) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final reply = "I see. You just said \"$userText\". Can you talk more about it?";
    final now = DateTime.now().toIso8601String();
    final aiMsg = ChatMessage(sender: "ai", text: reply, timestamp: now);

    // 1. add this AI message into _messages list
    setState(() {
      _messages.add(aiMsg);
    });
    _saveMessage(aiMsg);
    // 2. scroll to the bottom
    _scrollToBottomSoon();
  }

  // Helper Function call for auto scroll the chat to the bottom
  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve:Curves.easeOut,
        );
      }
    });
  }

  // UI bubble of a single message
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.sender == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
              ? const Radius.circular(16)
              : const Radius.circular(2),
            bottomRight: isUser
                ? const Radius.circular(2)
                : const Radius.circular(16),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // UI of chat message list area
  Widget _buildMessagesList() {
    return Expanded(
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            return _buildMessageBubble(msg);
          },
        ),
    );
  }

  // UI for the input field and send button
  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: "Say something with Momo...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
            ),
            const SizedBox(width: 8),
            // Send button
            IconButton(
                onPressed: _handleSend,
                icon: const Icon(Icons.send),
              color: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Momo Chat",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              IconButton(
                tooltip: "Clear chat history",
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  // 1. Clean the message table in DB
                  await DBHelper.clearMessages();
                  // 2. Clean the _messages list and rebuild UI
                  setState(() {
                    _messages.clear();
                  });
                },
              ),
            ],
          ),
        ),
        _buildMessagesList(),
        _buildInputArea(),
      ],
    );
  }
}
