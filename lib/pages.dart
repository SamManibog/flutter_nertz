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

  const HostingPage({
    super.key,
    required this.mainState,
    required this.onGameStart,
  });

  @override
  State<HostingPage> createState() => _HostingPageState();
}

class _HostingPageState extends State<HostingPage> {
  static const double marginSize = 30;
  late final MainState mainState;

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;

    NertzServer.bind(
      address: 'localhost',
      port: 8080,
      hostPlayerName: "host player",
      onGameStart: () {
        mainState.page = PageType.game;
        widget.onGameStart();
      },
    ).then((result) {
      setState(() {
        mainState.server = result.server;
        mainState.client = result.client;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (mainState.client == null) {
      return Center(
        child: Column(
          mainAxisAlignment: .start,
          children: [
            SizedBox(height: marginSize),
            Text('Hosting game...'),
          ],
        ),
      );
    }
    final List<Widget> children = [
      Text('Join Code:', style: Theme.of(context).textTheme.headlineSmall),
      Text(
        mainState.server!.joinKey,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      SizedBox(height: 20),
      Text(
        "${mainState.server!.hostPlayerName}'s Server",
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Divider(indent: 20, endIndent: 20),
    ];
    for (int playerId in mainState.server!.playerIds) {
      var cardChildren = <Widget>[
        Text(
          mainState.server!.clientName(playerId),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ];
      if (playerId != mainState.server!.hostId) {
        cardChildren.add(
          TapRegion(
            child: Icon(Icons.close),
            onTapInside: (_) => setState(() {
              mainState.server!.kickPlayer(playerId);
            }),
          ),
        );
      }
      children.add(
        Container(
          alignment: .center,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          width: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cardChildren,
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(height: marginSize),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: children,
            ),
          ),
          FilledButton(
            onPressed: () => mainState.server?.startGame(),
            child: Text('Start Game'),
          ),
          SizedBox(height: marginSize),
        ],
      ),
    );
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
