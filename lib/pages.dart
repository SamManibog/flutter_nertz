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

  /// games that were discovered
  List<PotentialGame> discoveredGames = [];

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
  final Function() onServerFailure;

  const HostingPage({
    super.key,
    required this.mainState,
    required this.onGameStart,
    required this.onServerFailure,
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

    void handleFailure(Object? error) {
      print("Failed to start server: $error");
      mainState.server = null;
      mainState.client = null;
      mainState.page = PageType.home;
      widget.onServerFailure();
    }

    try {
      NertzServer.bind(
        hostPlayerName: "Sam",
        onGameStart: () {
          mainState.page = PageType.game;
          widget.onGameStart();
        },
      ).then((result) {
        setState(() {
          mainState.server = result.server;
          mainState.client = result.client;
        });
      }, onError: handleFailure);
    } catch (e) {
      print("Failed to start server: $e");
      handleFailure(e);
    }
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
    var joinKeyStyle = Theme.of(context).textTheme.headlineLarge;
    if (joinKeyStyle != null) {
      joinKeyStyle = joinKeyStyle.copyWith(fontFamily: "RobotoMono");
    }
    final List<Widget> children = [
      Text('Join Code:', style: Theme.of(context).textTheme.headlineSmall),
      Text(mainState.server!.joinKey, style: joinKeyStyle),
      SizedBox(height: 20),
      Text(
        "${mainState.server!.hostPlayerName}'s Server",
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: .center,
      ),
      Divider(indent: 20, endIndent: 20),
    ];
    for (int playerId in mainState.server!.playerIds) {
      var cardChildren = <Widget>[
        Expanded(
          child: Text(
            mainState.server!.clientName(playerId),
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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

class JoiningPage extends StatefulWidget {
  final MainState mainState;

  const JoiningPage({super.key, required this.mainState});

  @override
  State<JoiningPage> createState() => _JoiningPageState();
}

class _JoiningPageState extends State<JoiningPage> {
  late final MainState mainState;

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Joining page not implemented yet"),
    );
  }
}
