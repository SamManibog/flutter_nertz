import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_nertz/nertz_networking.dart';
import 'package:flutter_nertz/nertz_widgets.dart';

const double pageMarginSize = 30;

enum PageType {
  /// the home page where you can choose to host or join a game
  home,

  /// the page shown while hosting a game, shows the join code and player list
  hosting,

  /// the page shown while searching for games to join, shows a list of discovered games
  searching,

  /// the page shown when attempting to join a game
  joining,

  /// the lobby page shown after joining a game
  lobby,

  /// the main page shown while playing a game
  game,

  /// the page shown after a game has ended, shows the winner and play again options
  gameOver,
}

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

  /// the socket used for discovering new games
  RawDatagramSocket? discoverySocket;
  bool allowDiscovery = false;

  /// the game that was selected to join
  PotentialGame? selectedGame;

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
            mainState.page = PageType.searching;
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
  final Function() onPlayerListUpdated;
  final Function() onServerFailure;
  final Function() onGameEnd;

  const HostingPage({
    super.key,
    required this.mainState,
    required this.onGameStart,
    required this.onPlayerListUpdated,
    required this.onServerFailure,
    required this.onGameEnd,
  });

  @override
  State<HostingPage> createState() => _HostingPageState();
}

class _HostingPageState extends State<HostingPage> {
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
        onPlayerListUpdated: () => widget.onPlayerListUpdated(),
        onGameEnd: () => widget.onGameEnd(),
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
            SizedBox(height: pageMarginSize),
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
        "${mainState.server!.hostPlayerName}'s Game",
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
          SizedBox(height: pageMarginSize),
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
          SizedBox(height: pageMarginSize),
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

class SearchingPage extends StatefulWidget {
  final MainState mainState;
  final Function() onGameSelected;

  const SearchingPage({
    super.key,
    required this.mainState,
    required this.onGameSelected,
  });

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  late final MainState mainState;
  final Set<PotentialGame> potentialGames = {PotentialGame.dummy()};

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;

    RawDatagramSocket.bind("255.255.255.255", discoveryPort).then(
      (socket) {
        if (!mainState.allowDiscovery) {
          socket.close();
          return;
        }
        mainState.discoverySocket = socket;
        mainState.discoverySocket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = mainState.discoverySocket?.receive();
            if (datagram == null) {
              return;
            }
            final game = PotentialGame.fromAdvertizementMessage(
              String.fromCharCodes(datagram.data),
              datagram.address,
            );
            if (game != null && !potentialGames.contains(game)) {
              setState(() {
                potentialGames.add(game);
              });
            }
          }
        });
      },
      onError: (error) {
        print("Failed to bind discovery socket: $error");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: .center,
        children: [
          SizedBox(height: pageMarginSize),
          Text(
            "Available Games:",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: .center,
          ),
          SizedBox(height: 10),
          for (PotentialGame game in potentialGames)
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
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${game.hostPlayerName}'s Game",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        "${game.hostAddress.address}:${game.hostPort}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () {
                      mainState.selectedGame = game;
                      mainState.page = PageType.joining;
                      widget.onGameSelected();
                    },
                    child: Text("Join"),
                  ),
                ],
              ),
            ),
          SizedBox(height: pageMarginSize),
        ],
      ),
    );
  }
}

class JoiningPage extends StatefulWidget {
  final MainState mainState;
  final void Function() onGameStart;
  final void Function() onPlayerListUpdated;
  final void Function() onGameEnd;

  const JoiningPage({
    super.key,
    required this.mainState,
    required this.onGameStart,
    required this.onPlayerListUpdated,
    required this.onGameEnd,
  });

  @override
  State<JoiningPage> createState() => _JoiningPageState();
}

class _JoiningPageState extends State<JoiningPage> {
  late bool attemptingConnection;
  late final MainState mainState;
  late final TextEditingController nameController;
  late final TextEditingController joinKeyController;

  @override
  void initState() {
    super.initState();
    attemptingConnection = false;
    mainState = widget.mainState;
    nameController = TextEditingController();
    joinKeyController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    late final void Function()? onJoinPressed;

    if (isValidPlayerName(nameController.text) &&
        joinKeyController.text.length == NertzServer.joinKeyLength &&
        !attemptingConnection) {
      onJoinPressed = () {
        attemptingConnection = true;
        NertzClient.connect(
          host: mainState.selectedGame!.hostAddress.address,
          port: mainState.selectedGame!.hostPort,
          playerName: nameController.text,
          joinKey: joinKeyController.text,
          onGameStart: () {
            mainState.page = PageType.game;
            widget.onGameStart();
          },
          onPlayerListUpdated: () => widget.onPlayerListUpdated(),
          onGameEnd: () => widget.onGameEnd(),
        ).then(
          (client) {
            setState(() {
              mainState.client = client;
              mainState.page = PageType.lobby;
              attemptingConnection = false;
            });
          },
          onError: (error) {
            setState(() => attemptingConnection = false);
          },
        );
      };
    } else {
      onJoinPressed = null;
    }

    return Container(
      alignment: .center,
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: pageMarginSize),
      child: Column(
        children: [
          Text("Joining", style: Theme.of(context).textTheme.headlineSmall),
          Text(
            "${mainState.selectedGame!.hostPlayerName}'s Game",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: .center,
          ),
          Text("Join Code:", style: Theme.of(context).textTheme.bodySmall),
          TextField(
            textAlign: .center,
            controller: joinKeyController,
            textCapitalization: .characters,
            decoration: InputDecoration(hintText: "Enter join code"),
            maxLength: NertzServer.joinKeyLength,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (value) {
              final newText = value
                  .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
                  .toUpperCase();
              setState(
                () => joinKeyController.value = TextEditingValue(text: newText),
              );
            },
          ),
          Text("Name:", style: Theme.of(context).textTheme.bodySmall),
          TextField(
            textAlign: .center,
            controller: nameController,
            decoration: InputDecoration(hintText: "Enter your name"),
            maxLength: maxNameLength,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (value) {
              late final String newText;
              try {
                newText = fixPlayerName(value);
              } catch (e) {
                newText = "";
              }
              setState(
                () => nameController.value = TextEditingValue(text: newText),
              );
            },
          ),
          ElevatedButton(onPressed: onJoinPressed, child: Text("Join Game")),
        ],
      ),
    );
  }
}

class LobbyPage extends StatelessWidget {
  final MainState mainState;

  const LobbyPage({super.key, required this.mainState});

  @override
  Widget build(BuildContext context) {
    var playerNameWidgets = <Widget>[];
    mainState.client!.playerNames.forEach((id, name) {
      playerNameWidgets.add(
        Container(
          alignment: .center,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          width: 300,
          child: Text(name, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
    });

    return Container(
      alignment: .center,
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: pageMarginSize),
      child: Column(
        children: [
          Text(
            "Waiting for host to start game...",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 20),
          Text(
            "Players in lobby:",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 10),
          ...playerNameWidgets,
        ],
      ),
    );
  }
}

class GameOverPage extends StatelessWidget {
  final MainState mainState;

  const GameOverPage({super.key, required this.mainState});

  @override
  Widget build(BuildContext context) {
    final winnerId = mainState.client?.winnerId();
    final winnerNameNullable = mainState.client?.playerNames[winnerId ?? -1];
    final winnerName = winnerNameNullable ?? "Unknown";

    late final List<Widget> content;
    if (winnerId == mainState.client?.playerId) {
      content = [
        Text("You won!", style: Theme.of(context).textTheme.headlineMedium),
      ];
    } else {
      content = [
        Text("Game Over!", style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 20),
        Text(
          "Winner: $winnerName",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ];
    }

    final List<Widget> buttons = [
      ElevatedButton(
        onPressed: () {
          mainState.client?.playAgain();
          mainState.page = PageType.lobby;
        },
        child: Text("Play Again"),
      ),
      SizedBox(height: 10),
      OutlinedButton(
        onPressed: () {
          mainState.client?.leaveGame();
          mainState.page = PageType.home;
        },
        child: Text("Return to Home"),
      ),
    ];

    return Container(
      alignment: .center,
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: pageMarginSize),
      child: Column(children: [
        ...content,
        ...buttons,
        ]),
    );
  }
}
