import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class ChatMessage {
  final String sender; // the user or the AI
  final String text;

  ChatMessage({
    required this.sender,
    required this.text,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  // chat message lists (right now store in memory)
  final List<ChatMessage> _messages = [
    ChatMessage(sender: "ai", text: "Hi, this is Momo. I am listening, how are you today?"),
  ];
  // TextField controller, use for getting the context from the input
  final TextEditingController _textController = TextEditingController();
  // scrollable control
  final ScrollController _scrollController = ScrollController();

  // Function call for user send message
  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 1. add this user message into _messages list
    setState(() {
      _messages.add(ChatMessage(sender: "user", text: text));
    });
    // clear the input field
    _textController.clear();
    // 2. auto create a fake AI reply
    _fakeAIReply(text);
    // 3. scroll to the bottom
    _scrollToBottomSoon();
  }

  // Function call for simulating AI reply
  void _fakeAIReply(String userText) {
    final reply = "I see. You just said \"$userText\". Can you talk more about it?";

    // 1. add this AI message into _messages list
    setState(() {
      _messages.add(ChatMessage(sender: "ai", text: reply));
    });
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
              : const Radius.circular(4),
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
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
          alignment: Alignment.centerLeft,
          child: const Text(
            "Momo",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _buildMessagesList(),
        _buildInputArea(),
      ],
    );
  }
}
