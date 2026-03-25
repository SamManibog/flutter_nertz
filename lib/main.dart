import 'package:flutter/material.dart';
import 'package:flutter_nertz/pages.dart';

// todo:
// - implement UDP broadcasts for LAN game discovery and connection
// - implement lobby page with player list and start game button
// - implement player kicking functionality for hosts
// - implement joining page
// - implement error handling for network messages
// - implement play again functionality
// - implement winning screen

void main() async {
  final MainState mainState = MainState();

  runApp(MyApp(mainState: mainState));
}

class MyApp extends StatelessWidget {
  final MainState mainState;

  const MyApp({super.key, required this.mainState});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: MyAppContents(mainState: mainState),
    );
  }
}

class MyAppContents extends StatefulWidget {
  final MainState mainState;

  const MyAppContents({super.key, required this.mainState});

  @override
  State<MyAppContents> createState() => _MyAppContentsState();
}

class _MyAppContentsState extends State<MyAppContents> {
  late final MainState mainState;

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;
  }

  @override
  Widget build(BuildContext context) {
    late final Widget currentPage;
    switch (mainState.page) {
      case PageType.home:
        currentPage = HomePage(
          mainState: mainState,
          onPageChange: () => setState(() {}),
        );
        break;
      case PageType.hosting:
        currentPage = HostingPage(
          mainState: mainState,
          onGameStart: () => setState(() {}),
        );
        break;
      case PageType.joining:
        throw UnimplementedError("Joining page not implemented yet");
        //currentPage = JoiningPage(mainState: mainState);
        break;
      case PageType.game:
        currentPage = GamePage(mainState: mainState);
        break;
    }
    return Scaffold(
      body: SafeArea(child: currentPage)
    );
  }
}