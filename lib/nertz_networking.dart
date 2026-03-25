import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_nertz/nertz.dart';

final playerNameRegex = RegExp(r'^[a-zA-Z0-9_!.? ]+$');
final maxNameLength = 20;

/// returns true if the given string is a valid player name
bool isValidPlayerName(String name) {
  return name.isNotEmpty &&
      name.length <= maxNameLength &&
      playerNameRegex.hasMatch(name);
}

/// fixes an invalid player name by removing invalid characters and truncating to the maximum length
String fixPlayerName(String name) {
  final validChars = name
      .split('')
      .where((char) => playerNameRegex.hasMatch(char))
      .join();
  if (validChars.isEmpty) {
    throw Exception("Player name '$name' is invalid and cannot be fixed");
  }
  return validChars.length <= maxNameLength
      ? validChars
      : validChars.substring(0, maxNameLength);
}

/// a map from network message types to their numeric type ids
const Map<Type, int> typeToIdMap = {
  LakePlacementRequest: 0,
  LakePlacementConfirmation: 1,
  GameStartNotification: 2,
  JoinConfirmation: 3,
  PlayerCountRequest: 4,
  PlayerCountAnswer: 5,
  JoinRequest: 6,
};

/// a map from numeric type ids to their network message types, used for deserialization
const Map<int, Type> idToTypeMap = {
  0: LakePlacementRequest,
  1: LakePlacementConfirmation,
  2: GameStartNotification,
  3: JoinConfirmation,
  4: PlayerCountRequest,
  5: PlayerCountAnswer,
  6: JoinRequest,
};

sealed class NertzNetworkMessage {
  String serialize();

  const NertzNetworkMessage();

  static String serializeMessage<T extends NertzNetworkMessage>(T message) {
    final typeId = typeToIdMap[message.runtimeType];
    assert(
      typeId != null,
      "Cannot serialize message of type ${message.runtimeType}: no type id defined for this type",
    );
    return jsonEncode({"type": typeId, "data": message.serialize()});
  }

  static (Type, String)? deserializeMessage(String data) {
    final decoded = jsonDecode(data);
    final Type? type = idToTypeMap[decoded["type"]];
    final String? messageData = decoded["data"];
    return (type != null && messageData != null) ? (type, messageData) : null;
  }
}

class GameStartNotification extends NertzNetworkMessage {
  final int playerCount;

  const GameStartNotification(this.playerCount);

  @override
  String serialize() {
    return jsonEncode({"playerCount": playerCount});
  }

  static GameStartNotification? deserialize(String data) {
    final decoded = jsonDecode(data);
    return GameStartNotification(decoded["playerCount"]);
  }
}

class JoinRequest extends NertzNetworkMessage {
  final String joinKey;
  final String name;

  JoinRequest({required this.joinKey, required this.name})
    : assert(name.length > 0, "Name cannot be empty"),
      assert(
        isValidPlayerName(name),
        "Name contains invalid characters: $name, only letters, numbers, and _!.? are allowed",
      );

  @override
  String serialize() {
    return jsonEncode({"joinKey": joinKey, "name": name});
  }

  static JoinRequest? deserialize(String data) {
    final decoded = jsonDecode(data);
    final String? name = decoded["name"];
    if (name == null || !isValidPlayerName(name)) {
      return null;
    }
    return JoinRequest(joinKey: decoded["joinKey"], name: decoded["name"]);
  }
}

class JoinConfirmation extends NertzNetworkMessage {
  final int? playerId;

  JoinConfirmation(this.playerId);

  @override
  String serialize() {
    return jsonEncode({"playerId": playerId});
  }

  static JoinConfirmation? deserialize(String data) {
    final decoded = jsonDecode(data);
    return JoinConfirmation(decoded["playerId"]);
  }
}

class PlayerCountRequest extends NertzNetworkMessage {
  const PlayerCountRequest();

  @override
  String serialize() {
    return jsonEncode({});
  }

  static PlayerCountRequest? deserialize(String data) {
    return PlayerCountRequest();
  }
}

class PlayerCountAnswer extends NertzNetworkMessage {
  final int playerCount;

  const PlayerCountAnswer(this.playerCount);

  @override
  String serialize() {
    return jsonEncode({"playerCount": playerCount});
  }

  static PlayerCountAnswer? deserialize(String data) {
    final decoded = jsonDecode(data);
    return PlayerCountAnswer(decoded["playerCount"]);
  }
}

class LakePlacementData {
  final int playerId;
  final PlayingCard card;
  final int lakeIndex;

  const LakePlacementData(this.playerId, this.card, this.lakeIndex);
}

/// a command to place a card in the lake, sent from the client to the server
class LakePlacementRequest extends NertzNetworkMessage {
  final LakePlacementData data;

  const LakePlacementRequest(this.data);

  @override
  String serialize() {
    return jsonEncode({
      "playerId": data.playerId,
      "card": {"suit": data.card.suit.index, "value": data.card.value.index},
      "lakeIndex": data.lakeIndex,
    });
  }

  static LakePlacementRequest? deserialize(String data) {
    final decoded = jsonDecode(data);
    return LakePlacementRequest(
      LakePlacementData(
        decoded["playerId"],
        PlayingCard(
          CardValue.values[decoded["card"]["value"]],
          CardSuit.values[decoded["card"]["suit"]],
        ),
        decoded["lakeIndex"],
      ),
    );
  }
}

/// a confirmation of a card placement in the lake, sent from the server to the client
class LakePlacementConfirmation extends NertzNetworkMessage {
  final int confirmationId;
  final LakePlacementData data;

  const LakePlacementConfirmation(this.data, this.confirmationId);

  @override
  String serialize() {
    return jsonEncode({
      "playerId": data.playerId,
      "card": {"suit": data.card.suit.index, "value": data.card.value.index},
      "lakeIndex": data.lakeIndex,
      "confirmationId": confirmationId,
    });
  }

  static LakePlacementConfirmation? deserialize(String data) {
    final decoded = jsonDecode(data);
    return LakePlacementConfirmation(
      LakePlacementData(
        decoded["playerId"],
        PlayingCard(
          CardValue.values[decoded["card"]["value"]],
          CardSuit.values[decoded["card"]["suit"]],
        ),
        decoded["lakeIndex"],
      ),
      decoded["confirmationId"],
    );
  }
}

class NertzClient {
  /// the socket for communicating with the server
  final Socket _socket;

  /// the subscription to the socket stream, using our onData callback
  //late final StreamSubscription _socketSubscription;

  /// a completer for initialization
  Completer<bool>? _initCompleter = Completer<bool>();

  /// the player's id in the game, assigned by the server
  int? playerId;

  int? playerCount;
  ClientLake? lake;
  PlayerState? playerState;

  final void Function() onGameStart;

  // creates a new client with the given socket, you must wait until _initCompleter is completed with a true value
  // before using the client
  NertzClient._(Socket socket, this.onGameStart) : _socket = socket {
    //_socketSubscription =
    _socket.map((data) => utf8.decode(data)).listen(_onData);
  }

  static Future<NertzClient?> connect({
    required String host,
    required int port,
    required String playerName,
    required String joinKey,
    required void Function() onGameStart,
  }) async {
    try {
      Socket socket = await Socket.connect(host, port);
      NertzClient client = NertzClient._(socket, onGameStart);

      // request to join the game with the given join key
      late final String safeName = fixPlayerName(playerName);

      print(
        "Sending join request with name '$safeName' and join key '$joinKey'",
      );
      socket.write(
        NertzNetworkMessage.serializeMessage(
          JoinRequest(joinKey: joinKey, name: safeName),
        ),
      );
      await socket.flush();
      print("Join request sent, waiting for confirmation...");

      // get join confirmation
      final initSuccess = await client._initCompleter!.future;
      client._initCompleter = null;
      if (initSuccess == true) {
        return client;
      } else {
        client.dispose();
        return null;
      }
    } catch (e) {
      print("Failed to connect to server: $e");
      return null;
    }
  }

  void dispose() {
    //_socketSubscription.cancel();
    _socket.close();
  }

  void _onData(String wrappedData) {
    int? typeId;
    late final String data;
    try {
      final decoded = jsonDecode(wrappedData);
      typeId = decoded["type"];
      data = decoded["data"];
    } catch (e) {
      print("Failed to deserialize data: '$wrappedData'");
      return;
    }

    if (typeId == null) {
      print("Received data of unspecified type");
      return;
    }

    Type? type = idToTypeMap[typeId];
    if (type == null) {
      print("Received data of unknown type: $typeId");
      return;
    }

    Map<Type, Function> actionMap = {
      LakePlacementConfirmation: () {
        final placementConfirmation = LakePlacementConfirmation.deserialize(
          data,
        );
        if (placementConfirmation != null) {
          print("client recieved placement confirmation.");
          lake?._handlePlacement(placementConfirmation);
        }
      },

      PlayerCountAnswer: () {
        final playerCountAnswer = PlayerCountAnswer.deserialize(data);
        if (playerCountAnswer != null) {
          playerCount = playerCountAnswer.playerCount;
        }
      },

      JoinConfirmation: () {
        if (_initCompleter == null) {
          return;
        }
        final joinConfirmation = JoinConfirmation.deserialize(data);
        if (joinConfirmation != null) {
          if (joinConfirmation.playerId != null) {
            if (playerId != null && playerId != joinConfirmation.playerId) {
              print(
                "Received join confirmation with mismatching player id: ${joinConfirmation.playerId}, expected $playerId",
              );
            } else {
              playerId = joinConfirmation.playerId;
              _initCompleter!.complete(true);
              print("Successfully joined game with player id $playerId");
            }
          } else {
            _initCompleter!.complete(false);
            print("Failed to join game: invalid join key");
          }
        }
      },

      GameStartNotification: () {
        final gameStartInfo = GameStartNotification.deserialize(data);
        if (gameStartInfo == null) {
          print("Failed to deserialize game start notification");
          return;
        }
        playerCount = gameStartInfo.playerCount;
        lake = ClientLake._(
          playerId: playerId!,
          lakeData: LakeData.withSize(playerCount!),
          makePlacementRequest: (request) {
            _socket.write(NertzNetworkMessage.serializeMessage(request));
            _socket.flush();
          },
        );
        playerState = PlayerState.newRandom(lake!);
        onGameStart.call();
      },
    };

    final action = actionMap[type];
    if (action == null) {
      print("Client received data of unimplemented type: $type");
    } else {
      action.call();
    }
  }
}

class ClientLake {
  final int _playerId;
  final LakeData lakeData;
  int _lastConfirmationId = -1;
  void Function(LakePlacementRequest) makePlacementRequest;

  Completer<bool>? cardPlacementCompleter;

  LakePlacementRequest? queuedPlacement;

  void _handlePlacement(LakePlacementConfirmation placementData) {
    // check that confirmations are in order
    assert(
      placementData.confirmationId == _lastConfirmationId + 1,
      "Received out of order confirmation: ${placementData.confirmationId}, expected ${_lastConfirmationId + 1}",
    );

    // if defined, complete our queued placement with this value
    bool? completion;

    // handle cases involving our queued placement
    if (queuedPlacement != null) {
      // ensure that if the recieved placement is for this player, it matches the queued placement
      if (placementData.data.playerId == _playerId) {
        assert(
          queuedPlacement!.data.card == placementData.data.card,
          "server confirmed placement of a different card than the one we queued",
        );
        assert(
          queuedPlacement!.data.lakeIndex == placementData.data.lakeIndex,
          "server confirmed placement in a different lake index than the one we queued",
        );
      }

      // check if we want to confirm our placment
      if (queuedPlacement!.data.lakeIndex == placementData.data.lakeIndex) {
        // placement was successful if placementData.data.playerId matches our player id
        // otherwise, another player placed their card first and we failed to place our card
        completion = placementData.data.playerId == _playerId;
        queuedPlacement = null;
      }
    }

    // place the card, checking that the placement was valid
    assert(
      lakeData.placeCard(placementData.data.card, placementData.data.lakeIndex),
      "server confirmed placement that was invalid according to client's lake data",
    );
    _lastConfirmationId++;
    if (completion != null) {
      final completer = cardPlacementCompleter;
      cardPlacementCompleter = null;
      completer?.complete(completion);
    }
  }

  ClientLake._({
    required int playerId,
    required this.lakeData,
    required this.makePlacementRequest,
  }) : _playerId = playerId,
       cardPlacementCompleter = Completer<bool>();

  /// attempts to place a card in the lake, returning true if successful
  Future<bool> placeCard(PlayingCard card, int index) async {
    if (queuedPlacement != null) {
      return false;
    }
    queuedPlacement = LakePlacementRequest(
      LakePlacementData(_playerId, card, index),
    );
    makePlacementRequest(queuedPlacement!);
    cardPlacementCompleter = Completer<bool>();
    return cardPlacementCompleter!.future;
  }
}

class NertzServer {
  static const int joinKeyLength = 10;
  static const int maxNameLength = 20;

  late final int hostId;
  final String hostPlayerName;
  final String joinKey;
  final ServerSocket _serverSocket;
  final List<Socket> _clients = [];
  final Map<Socket, int> _clientToId = {};
  final Map<int, Socket> _idToClient = {};
  final Map<int, String> _idToName = {};
  final List<String> _usedNames = [];
  int _nextPlayerId = 0;

  int _confirmationCounter = 0;
  LakeData? _lakeData;

  int get playerCount => _clients.length;
  String clientName(int playerId) => _idToName[playerId] ?? "Unknown Player";
  Iterable<int> get playerIds =>
      _clients.map((client) => _clientToId[client]!);

  void kickPlayer(int playerId) {
    if (playerId == hostId) {
      return;
    }
    Socket? client = _idToClient[playerId];
    if (client == null) {
      return;
    }
    _idToClient.remove(playerId);
    _clientToId.remove(client);
    _idToName.remove(playerId);
    _clients.remove(client);
    _usedNames.remove(clientName(playerId));
    client.close();
  }

  void startGame() {
    // check that game isn't already started
    if (_lakeData != null) {
      return;
    }

    // initialize data
    _lakeData = LakeData.withSize(_clients.length);
    _confirmationCounter = 0;

    // send game start notification to all clients
    for (var client in _clients) {
      client.write(
        NertzNetworkMessage.serializeMessage(
          GameStartNotification(_clients.length),
        ),
      );
      client.flush();
    }
  }

  void processJoinRequest(Socket client, JoinRequest joinRequest) {
    // verify join key
    if (joinRequest.joinKey == joinKey) {
      // accept join request
      if (_clientToId.containsKey(client)) {
        print(
          "Client ${client.remoteAddress.address}:${client.remotePort} attempted to join but is already in the game",
        );
        return;
      }
      if (_usedNames.contains(joinRequest.name)) {
        print(
          "Client ${client.remoteAddress.address}:${client.remotePort} attempted to join with duplicate name '${joinRequest.name}' but that name is already taken",
        );
        client.write(
          NertzNetworkMessage.serializeMessage(JoinConfirmation(null)),
        );
        client.flush();
        client.close();
        return;
      }
      int playerId = _nextPlayerId++;
      _clientToId[client] = playerId;
      _idToName[playerId] = joinRequest.name;
      _usedNames.add(joinRequest.name);
      _clients.add(client);
      print(
        "Client ${client.remoteAddress.address}:${client.remotePort} joined with player id $playerId",
      );

      // send join confirmation
      client.write(
        NertzNetworkMessage.serializeMessage(JoinConfirmation(playerId)),
      );
      client.flush();
    } else {
      // reject join request
      print(
        "Client ${client.remoteAddress.address}:${client.remotePort} provided invalid join key, rejecting",
      );
      client.write(
        NertzNetworkMessage.serializeMessage(JoinConfirmation(null)),
      );
      client.flush();
      client.close();
    }
  }

  void _onClientData(Socket client, String wrappedData) async {
    print(
      "recieved data from client ${client.remoteAddress.address}:${client.remotePort}: $wrappedData",
    );
    int? typeId;
    late final String data;
    try {
      final decoded = jsonDecode(wrappedData);
      typeId = decoded["type"];
      data = decoded["data"];
    } catch (e) {
      print("Failed to deserialize data: '$wrappedData'");
      return;
    }

    if (typeId == null) {
      print("Received data of unspecified type");
      return;
    }

    Type? type = idToTypeMap[typeId];
    if (type == null) {
      print("Received data of unknown type: $typeId");
      return;
    }

    // check if this is a join request, if so handle it without checking for registration
    if (type == JoinRequest) {
      // deserialize request
      final joinRequest = JoinRequest.deserialize(data);
      if (joinRequest == null) {
        print(
          "Failed to deserialize join request from client ${client.remoteAddress.address}:${client.remotePort}",
        );
        return;
      }

      processJoinRequest(client, joinRequest);
      return;
    }

    // ensure registration then handle data
    if (!_clientToId.containsKey(client)) {
      print("Recieved data from unregistered client.");
      return;
    }
    Map<Type, Function> actionMap = {
      LakePlacementRequest: () {
        // deserialize request
        final placementRequest = LakePlacementRequest.deserialize(data);
        if (placementRequest == null) {
          print(
            "Failed to deserialize lake placement request from client ${client.remoteAddress.address}:${client.remotePort}",
          );
          return;
        }

        // validate request
        if (_lakeData == null) {
          print(
            "Received lake placement request before game started, ignoring",
          );
          return;
        }
        int playerId = _clientToId[client]!;
        if (placementRequest.data.playerId != playerId) {
          print(
            "Received lake placement request from client ${client.remoteAddress.address}:${client.remotePort} with mismatching player id ${placementRequest.data.playerId}, expected $playerId, ignoring",
          );
          return;
        }

        // attempt to place the card, and if successful, send a confirmation to all clients
        if (_lakeData!.placeCard(
          placementRequest.data.card,
          placementRequest.data.lakeIndex,
        )) {
          final confirmation = LakePlacementConfirmation(
            placementRequest.data,
            _confirmationCounter++,
          );
          for (var c in _clients) {
            c.write(NertzNetworkMessage.serializeMessage(confirmation));
            c.flush();
          }
        }
      },
    };

    final action = actionMap[type];
    if (action == null) {
      print("Server received data of unimplemented type: $type");
    } else {
      action.call();
    }
  }

  void _handleConnection(Socket client) {
    print(
      "New client connected: ${client.remoteAddress.address}:${client.remotePort}",
    );
    client
        .map((data) => utf8.decode(data))
        .listen(
          (data) => _onClientData(client, data),
          onDone: () => print(
            "Client disconnected: ${client.remoteAddress.address}:${client.remotePort}",
          ),
          onError: (error) => print(
            "Error with client ${client.remoteAddress.address}:${client.remotePort}: $error",
          ),
        );
  }

  NertzServer._(this._serverSocket, this.joinKey, this.hostPlayerName) {
    _serverSocket.listen(_handleConnection);
  }

  /// generates a join key
  static String generateJoinKey() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    return String.fromCharCodes(
      Iterable.generate(
        joinKeyLength,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  static Future<({NertzServer server, NertzClient client})> bind({
    required String address,
    required int port,
    required String hostPlayerName,
    required void Function() onGameStart,
  }) async {
    ServerSocket serverSocket = await ServerSocket.bind(address, port);
    final joinKey = generateJoinKey();
    final server = NertzServer._(serverSocket, joinKey, hostPlayerName);
    final client = await NertzClient.connect(
      host: serverSocket.address.address,
      port: serverSocket.port,
      joinKey: joinKey,
      playerName: hostPlayerName,
      onGameStart: onGameStart,
    );
    if (client == null) {
      serverSocket.close();
      throw Exception("Failed to connect to same-device server");
    }
    server.hostId = client.playerId!;
    return (server: server, client: client);
  }
}
