import 'package:flutter/material.dart';
import 'package:flutter_nertz/card_widgets.dart';
import 'package:flutter_nertz/nertz.dart';
import 'package:flutter_nertz/nertz_networking.dart';
import 'package:flutter_nertz/pages.dart';

class PlayerUi extends StatefulWidget {
  final MainState mainState;
  final PlayerState playerState;
  final ClientLake lakeState;
  final int playerCount;

  const PlayerUi({
    super.key,
    required this.mainState,
    required this.playerState,
    required this.lakeState,
    required this.playerCount,
  });

  @override
  State<PlayerUi> createState() => _PlayerUiState();
}

class _PlayerUiState extends State<PlayerUi> {
  /// the main state of the app, used for sending commands to the server
  late final MainState mainState;

  /// the number of players in the game
  late final int playerCount;

  /// the state of the player this ui represents
  late final PlayerState playerState;

  /// the lake that this ui represents
  late final ClientLake lakeState;

  /// the global key of the main stack, used for calculating drag positions relative to the stack
  late final GlobalKey _mainKey;

  /// the keys of the river stacks, used for calculating drag:drop positions
  late final List<GlobalKey> _riverStackKeys;

  /// the keys of the lake stacks, used for calculating drag:drop positions
  late final List<GlobalKey> _lakeStackKeys;

  /// the grace distance for placements onto the river
  static const Offset riverPlacementGrace = Offset(15, 20);

  /// the last postition of the moved hand
  Offset _lastDragPosition = Offset.zero;

  void _updateDragPosition(DragUpdateDetails details) {
    if (playerState.handOccupied) {
      setState(() {
        _lastDragPosition = details.globalPosition;
      });
    }
  }

  void _endDrag(DragEndDetails details) {
    bool keyContainsPosition(GlobalKey key) {
      final riverStackBox =
          (key.currentContext?.findRenderObject() as RenderBox?);
      if (riverStackBox == null) {
        return false;
      }
      final riverStackPosition = riverStackBox.localToGlobal(Offset.zero);
      final riverStackSize = riverStackBox.size;
      final riverStackRect = Rect.fromLTWH(
        riverStackPosition.dx - riverPlacementGrace.dx,
        riverStackPosition.dy - riverPlacementGrace.dy,
        riverStackSize.width + 2 * riverPlacementGrace.dx,
        riverStackSize.height + 2 * riverPlacementGrace.dy,
      );
      return riverStackRect.contains(details.globalPosition);
    }

    if (playerState.handOccupied) {
      for (int riverIndex = 0; riverIndex < 4; riverIndex++) {
        if (keyContainsPosition(_riverStackKeys[riverIndex])) {
          setState(() {
            playerState.handleCommand(HandToRiverCommand(riverIndex));
          });
          return;
        }
      }
      for (int suitIndex = 0; suitIndex < 4; suitIndex++) { 
        for (int stackIndex = 0; stackIndex < playerCount; stackIndex++) {
          if (keyContainsPosition(
            _lakeStackKeys[suitIndex * playerCount + stackIndex],
          )) {
            final suit = CardSuit.values[suitIndex];
            if (playerState.handSize > 1 || playerState.handBottomSuit! != suit) {
              setState(() => playerState.handleCommand(CancelHandCommand()));
              return;
            }
            print("Placing card in lake suit $suitIndex stack $stackIndex");
            setState(() => playerState.handleCommand(CancelHandCommand()));
            return;
          }
        }
      }
    }
    setState(() => playerState.handleCommand(CancelHandCommand()));
  }

  Widget buildLake() {
    final lakeData = lakeState.lakeData;
    List<Widget> suitColumns = [];
    for (int suitIndex = 0; suitIndex < 4; suitIndex++) {
      final suit = CardSuit.values[suitIndex];
      List<PlayingCard?> cardsInSuit = lakeData.getSuitList(suit);
      List<Widget> suitColumnChildren = [];
      for (int i = 0; i < playerCount; i++) {
        late final Widget suitPlaceholder;

        if (cardsInSuit[i] == null) {
          suitPlaceholder = Container(
            width: HalfCardPainter.size.width,
            height: HalfCardPainter.size.height,
            color: Colors.green,
            child: Text(suit.unicode, style: TextStyle(fontSize: 14)),
          );
        } else {
          suitPlaceholder = CustomPaint(
            painter: HalfCardPainter(cardsInSuit[i]!),
            size: HalfCardPainter.size,
          );
        }

        suitColumnChildren.add(
          Container(
            key: _lakeStackKeys[suitIndex * playerCount + i],
            child: suitPlaceholder,
          ),
        );
      }

      suitColumns.add(Column(spacing: 10, children: suitColumnChildren));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: suitColumns,
    );
  }

  Widget buildNertzPile() {
    final nertzPainter = playerState.nertzPainter;
    var nertzPileStackChildren = <Widget>[];
    if (nertzPainter != null) {
      nertzPileStackChildren.add(
        CustomPaint(painter: nertzPainter, size: CardPainter.size),
      );
    } else {
      nertzPileStackChildren.add(
        Container(
          width: CardPainter.size.width,
          height: CardPainter.size.height,
          color: Colors.green,
        ),
      );
    }
    nertzPileStackChildren.add(
      playerState.nertzInteractable(
        onDragStarted: (details, cardIndex) {
          if (playerState.handleCommand(NertzToHandCommand())) {
            setState(() {
              _lastDragPosition = details.globalPosition;
            });
          }
        },
        onDragUpdated: _updateDragPosition,
        onDragEnded: _endDrag,
      ),
    );
    return Stack(children: nertzPileStackChildren);
  }

  Widget buildStream() {
    var streamChildren = <Widget>[];

    void onWasteDragStart(DragStartDetails details) {
      if (playerState.handleCommand(WasteToHandCommand())) {
        setState(() {
          _lastDragPosition = details.globalPosition;
        });
      }
    }

    // allocate space for the entire widget
    streamChildren.add(
      SizedBox(
        width: CardPainter.size.width,
        height: CardPainter.size.height * 3,
      ),
    );

    // create waste pile
    final wastePainter = playerState.wastePainter;
    if (wastePainter != null) {
      streamChildren.add(
        CustomPaint(painter: wastePainter, size: CardPainter.size),
      );
    } else {
      streamChildren.add(
        Container(
          width: CardPainter.size.width,
          height: CardPainter.size.height,
          color: Colors.green,
        ),
      );
    }
    final wasteGestureDetectorOffset =
        (playerState.wasteSize - 1).clamp(0, 2) * CardStackPainter.offsetY;
    streamChildren.add(
      Positioned(
        top: wasteGestureDetectorOffset,
        child: GestureDetector(
          behavior: .translucent,
          onHorizontalDragStart: onWasteDragStart,
          onVerticalDragStart: onWasteDragStart,
          onHorizontalDragUpdate: _updateDragPosition,
          onVerticalDragUpdate: _updateDragPosition,
          onHorizontalDragEnd: _endDrag,
          onVerticalDragEnd: _endDrag,
          child: SizedBox(
            width: CardPainter.size.width,
            height: CardPainter.size.height,
          ),
        ),
      ),
    );

    // create stock pile
    final stockPainter = playerState.stockPainter;
    if (stockPainter != null) {
      streamChildren.add(
        Positioned(
          top: CardPainter.size.height * 2,
          child: GestureDetector(
            behavior: .translucent,
            onTap: () {
              setState(() => playerState.handleCommand(FeedWasteCommand()));
            },
            child: CustomPaint(painter: stockPainter, size: CardPainter.size),
          ),
        ),
      );
    } else {
      streamChildren.add(
        Positioned(
          top: CardPainter.size.height * 2,
          child: GestureDetector(
            behavior: .translucent,
            onTap: () {
              setState(() => playerState.handleCommand(ResetStockCommand()));
            },
            child: Container(
              width: CardPainter.size.width,
              height: CardPainter.size.height,
              color: Colors.green,
            ),
          ),
        ),
      );
    }

    return Stack(children: streamChildren);
  }

  Widget buildRiver() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: List.generate(4, (int riverIndex) {
        final riverStackChildren = <Widget>[];
        final interactable = playerState.riverStackInteractable(
          riverIndex,
          key: _riverStackKeys[riverIndex],
          onDragStarted: (details, cardIndex) {
            if (playerState.handleCommand(
              RiverToHandCommand(riverIndex, cardIndex),
            )) {
              setState(() {
                _lastDragPosition = details.globalPosition;
              });
            }
          },
          onDragUpdated: _updateDragPosition,
          onDragEnded: _endDrag,
        );
        if (playerState.riverStackSize(riverIndex) <= 0) {
          riverStackChildren.add(
            Container(
              width: CardPainter.size.width,
              height: CardPainter.size.height,
              color: Colors.green,
            ),
          );
        }
        riverStackChildren.add(interactable);
        return Stack(children: riverStackChildren);
      }),
    );
  }

  Widget buildPersonalUi() {
    final nertzPile = buildNertzPile();
    final theStream = buildStream();
    final theRiver = buildRiver();

    // create ui that is affected only by the current player
    return Row(
      mainAxisAlignment: .center,
      crossAxisAlignment: .start,
      children: [
        Column(
          mainAxisAlignment: .start,
          crossAxisAlignment: .center,
          children: [nertzPile, const SizedBox(height: 40), theStream],
        ),
        const SizedBox(width: 20),
        theRiver,
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    mainState = widget.mainState;
    lakeState = widget.lakeState;
    playerState = widget.playerState;
    playerCount = widget.playerCount;
    _lakeStackKeys = List.generate(
      4 * widget.playerCount,
      (index) => GlobalKey(),
    );
    _riverStackKeys = List.generate(4, (index) => GlobalKey());
    _mainKey = GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final lake = buildLake();
    final personalUi = buildPersonalUi();

    final tableUi = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 40,
      children: [lake, personalUi],
    );

    final gameUiChildren = <Widget>[tableUi];
    final mainPosition =
        (_mainKey.currentContext?.findRenderObject() as RenderBox?)
            ?.localToGlobal(Offset.zero) ??
        Offset.zero;
    final handPainter = playerState.handPainter(
      _lastDragPosition -
          mainPosition -
          Offset(CardPainter.size.width / 2, CardPainter.size.height / 4),
    );
    if (handPainter != null) {
      gameUiChildren.add(handPainter);
    }

    return Stack(key: _mainKey, children: gameUiChildren);
  }
}
