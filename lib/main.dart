import 'package:flutter/material.dart';
import 'package:flutter_nertz/pages.dart';

// todo:
// - refactor to include client lake in player state
// - implement HandToLake command and its handler
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
    return SafeArea(child: currentPage);
  }
}

/*
class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  late final PlayerState playerState;

  @override
  void initState() {
    super.initState();
    playerState = PlayerState.newRandom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            PlayerUi(playerState: playerState),
            FilledButton(
              onPressed: () async {
                final server =
                    await NertzServer.bind('localhost', 8080);
                final client = await NertzClient.connect(
                  host: '127.0.0.1',
                  port: 8080,
                  joinKey: server.joinKey,
                  playerName: "Sam",
                );
                if (client == null) {
                  print('Failed to connect to server');
                } else {
                  print('Client connected with id ${client.playerId}');
                }
              },
              child: SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
  }
}
*/
