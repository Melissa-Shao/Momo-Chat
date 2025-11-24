import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'memories_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [ChatScreen(), MemoriesScreen(),];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // major screen, will change the screen based on the page index
      body: _screens[_currentIndex],

      // bottom navbar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (newIndex) {
          setState(() {
            _currentIndex = newIndex;
          });
        },
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label:"Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label:"Memories",
          ),
        ],
      ),
    );
  }
}