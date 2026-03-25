import 'package:flutter/material.dart';
import 'package:flutter_nertz/nertz_networking.dart';
import 'package:flutter_nertz/nertz_widgets.dart';

enum PageType { home, hosting, joining, game }

/// the main state of the app
class MainState {
  /// if connected to a game, will be non-null
  NertzClient? client;

  /// if hosting a game, will be non-null
  NertzServer? server;

  /// the page currently being displayed
  PageType page = PageType.home;

  MainState();
}

class HomePage extends StatelessWidget {
  final MainState mainState;
  final Function() onPageChange;

  const HomePage({
    super.key,
    required this.mainState,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(
            "Nertz!",
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            mainState.page = PageType.joining;
            onPageChange();
          },
          child: Text("Join Game"),
        ),
        ElevatedButton(
          onPressed: () {
            mainState.page = PageType.hosting;
            onPageChange();
          },
          child: Text("Host Game"),
        ),
      ],
    );
  }
}

class HostingPage extends StatefulWidget {
  final MainState mainState;
  final Function() onGameStart;

  const HostingPage({super.key, required this.mainState, required this.onGameStart});

  @override
  State<HostingPage> createState() => _HostingPageState();
}

class _HostingPageState extends State<HostingPage> {
  late final MainState mainState;

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;

    NertzServer.bind('localhost', 8080).then((server) {
      mainState.server = server;
      NertzClient.connect(
        host: '127.0.0.1',
        port: 8080,
        joinKey: server.joinKey,
        playerName: "Sam",
        onGameStart: () {
          mainState.page = PageType.game;
          widget.onGameStart();
        },
      ).then((client) {
        if (client == null) {
          print('Failed to connect to same-device server');
        } else {
          print(
            'Client connected to same-device serverwith id ${client.playerId}',
          );
          setState(() {
            mainState.client = client;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    if (mainState.client != null) {
      children.add(
        Text('Hosting game with join key: ${mainState.server!.joinKey}'),
      );
      children.add(
        FilledButton(
          onPressed: () => mainState.server?.startGame(),
          child: Text('Start Game'),
        ),
      );
    } else {
      children.add(Text('Setting up server...'));
    }
    return Column(spacing: 20, children: children);
  }
}

class GamePage extends StatefulWidget {
  final MainState mainState;

  const GamePage({super.key, required this.mainState});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MainState mainState;

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;
  }

  @override
  Widget build(BuildContext context) {
    return PlayerUi(
      mainState: mainState,
      playerState: mainState.client!.playerState!,
      lakeState: mainState.client!.lake!,
      playerCount: mainState.client!.playerCount!,
    );
  }
}
