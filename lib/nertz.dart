import 'package:flutter/material.dart';
import 'package:flutter_nertz/card_widgets.dart';

enum CardColor { red, black }

enum CardSuit {
  clubs(color: .black, unicode: "♣"),
  hearts(color: .red, unicode: "♥"),
  spades(color: .black, unicode: "♠"),
  diamonds(color: .red, unicode: "♦");

  const CardSuit({required this.color, required this.unicode});

  final CardColor color;
  final String unicode;
}

enum CardValue {
  ace(pipText: "A"),
  two(pipText: "2"),
  three(pipText: "3"),
  four(pipText: "4"),
  five(pipText: "5"),
  six(pipText: "6"),
  seven(pipText: "7"),
  eight(pipText: "8"),
  nine(pipText: "9"),
  ten(pipText: "10"),
  jack(pipText: "J"),
  queen(pipText: "Q"),
  king(pipText: "K");

  /// the value of the card immediately below this one
  CardValue? get previousValue {
    if (this == ace) {
      return null;
    } else {
      return CardValue.values[index - 1];
    }
  }

  /// the value of the card immediately above this one
  CardValue? get nextValue {
    if (this == king) {
      return null;
    } else {
      return CardValue.values[index + 1];
    }
  }

  /// the text to display on the pip for this card value
  final String pipText;

  const CardValue({required this.pipText});
}

class PlayingCard {
  const PlayingCard(this.value, this.suit);

  final CardSuit suit;
  final CardValue value;

  /// returns true if this card can be placed on top of the other card in the river
  bool riverCanPlaceOn(PlayingCard other) {
    return suit.color != other.suit.color &&
        value.nextValue?.index == other.value.index;
  }

  /// returns true if this card can be placed on top of the other card in the lake
  bool lakeCanPlaceOn(PlayingCard other) {
    return suit == other.suit &&
        value.previousValue?.index == other.value.index;
  }

  // creates a standard 52 card deck
  static List<PlayingCard> makeDeck() {
    List<PlayingCard> deck = [];
    for (CardSuit suit in CardSuit.values) {
      for (CardValue value in CardValue.values) {
        deck.add(PlayingCard(value, suit));
      }
    }
    return deck;
  }

  @override
  String toString() {
    return '${value.name} of ${suit.name}';
  }

  @override
  bool operator ==(Object other) {
    if (other is PlayingCard) {
      return suit.index == other.suit.index && value.index == other.value.index;
    }
    return false;
  }

  @override
  int get hashCode => suit.index * 13 + value.index;
}

/// a stack of cards in the river
class RiverCardStack {
  /// the cards on this stack, with the top card at the end of the list
  final List<PlayingCard> cards;

  /// returns true if this stack is empty
  bool get isEmpty => cards.isEmpty;

  RiverCardStack({required this.cards}) {
    for (int i = 1; i < cards.length; i++) {
      assert(cards[i].riverCanPlaceOn(cards[i - 1]));
    }
  }

  RiverCardStack.empty() : cards = [];

  /// returns true if this stack can be placed on top of the other stack in the river
  bool riverCanPlaceOn(RiverCardStack other) {
    if (cards.isEmpty || other.cards.isEmpty) {
      return true;
    }
    return cards[0].riverCanPlaceOn(other.cards.last);
  }

  /// returns true if this stack can be placed on top of the given lake card
  bool lakeCanPlaceOn(PlayingCard other) {
    return cards.length == 1 && cards[0].lakeCanPlaceOn(other);
  }

  /// add another card stack onto this stack, if possible
  bool append(RiverCardStack other) {
    if (!other.riverCanPlaceOn(this)) {
      return false;
    }
    cards.addAll(other.cards);
    return true;
  }

  /// splits the stack at the given index, returning the top stack
  RiverCardStack splitAt(int index) {
    assert(index >= 0 && index < cards.length);
    List<PlayingCard> topCards = cards.sublist(index);
    cards.removeRange(index, cards.length);
    return RiverCardStack(cards: topCards);
  }

  /// gets the painter for this stack
  CardStackPainter get painter => CardStackPainter(cards);

  /// gets the interactable stack for this stack, with the given drag handlers
  InteractableCardStack interactable({
    Key? key,
    required void Function(DragStartDetails, int) onDragStarted,
    required void Function(DragUpdateDetails) onDragUpdated,
    required void Function(DragEndDetails) onDragEnded,
  }) {
    return InteractableCardStack(
      key: key,
      cards: cards,
      onDragStarted: onDragStarted,
      onDragUpdated: onDragUpdated,
      onDragEnded: onDragEnded,
    );
  }
}

enum HandOrigin {
  river1,
  river2,
  river3,
  river4,
  waste,
  nertz;

  int get riverIndex {
    switch (this) {
      case HandOrigin.river1:
        return 0;
      case HandOrigin.river2:
        return 1;
      case HandOrigin.river3:
        return 2;
      case HandOrigin.river4:
        return 3;
      default:
        throw Exception('Not a river origin');
    }
  }
}

/// a command to move cards in a player's state
sealed class PlayerCommand {
  final bool needsClearHand;

  const PlayerCommand(this.needsClearHand);
}

/// moves a stack of cards from the river to the player's hand
class RiverToHandCommand extends PlayerCommand {
  final int riverIndex;
  final int splitIndex;

  const RiverToHandCommand(this.riverIndex, this.splitIndex)
    : assert(riverIndex >= 0 && riverIndex < 4),
      assert(splitIndex >= 0),
      super(true);
}

/// moves the top card from the waste pile to the player's hand
class WasteToHandCommand extends PlayerCommand {
  const WasteToHandCommand() : super(true);
}

/// moves the top card from the nertz pile to the player's hand
class NertzToHandCommand extends PlayerCommand {
  const NertzToHandCommand() : super(true);
}

/// moves the card from the player's hand to the river, if possible
class HandToRiverCommand extends PlayerCommand {
  final int riverIndex;
  const HandToRiverCommand(this.riverIndex) : super(false);
}

/// cancels the player's current hand, returning cards to their origin
class CancelHandCommand extends PlayerCommand {
  const CancelHandCommand() : super(false);
}

/// feeds the waste pile with up to three cards from the stock pile
class FeedWasteCommand extends PlayerCommand {
  const FeedWasteCommand() : super(false);
}

/// resets the stock pile by moving all cards from the waste pile back to the stock pile
class ResetStockCommand extends PlayerCommand {
  const ResetStockCommand() : super(false);
}

/// rotates the stock pile by moving the top card to the bottom of the pile
class RotateStockCommand extends PlayerCommand {
  const RotateStockCommand() : super(false);
}

class PlayerState {
  /// the contents and position of the player's hand
  (RiverCardStack, HandOrigin, Offset)? _hand;

  /// the stacks in the player's river
  final List<RiverCardStack> _riverStacks;

  /// the player's stock pile
  final List<PlayingCard> _stockPile;

  /// the player's waste pile
  final List<PlayingCard> _wastePile;

  /// the player's nertz pile
  final List<PlayingCard> _nertzPile;

  /// whether the top card of the nertz pile should be face up
  bool _showNertzTopCard = true;

  /// whether the top card of the nertz pile should be face up
  bool get showNertzTopCard => _showNertzTopCard;

  /// gets the size of the given river stack
  int riverStackSize(int index) {
    return _riverStacks[index].cards.length;
  }

  /// gets the size of the waste pile
  int get wasteSize => _wastePile.length;

  /// gets the size of the nertz pile
  int get nertzSize => _nertzPile.length;

  /// gets the size of the stock pile
  int get stockSize => _stockPile.length;

  /// gets the painter for the nertz pile, if it exists
  /// should b elayerd underneath the result of nertzInteractable
  CardPainter? get nertzPainter {
    if (_nertzPile.isEmpty) {
      return null;
    }
    return CardPainter(null);
  }

  /// gets the interactable for the nertz pile
  InteractableCardStack nertzInteractable({
    required void Function(DragStartDetails, int) onDragStarted,
    required void Function(DragUpdateDetails) onDragUpdated,
    required void Function(DragEndDetails) onDragEnded,
  }) {
    late final List<PlayingCard> cards;
    if (_nertzPile.isEmpty || !_showNertzTopCard) {
      cards = [];
    } else {
      cards = [_nertzPile.last];
    }
    return InteractableCardStack(
      cards: cards,
      onDragStarted: onDragStarted,
      onDragUpdated: onDragUpdated,
      onDragEnded: onDragEnded,
    );
  }

  /// gets the painter for the waste pile, if it exists
  CardStackPainter? get wastePainter {
    if (_wastePile.isEmpty) {
      return null;
    }
    var cardCount = _wastePile.length;
    if (_hand != null && _hand!.$2 == HandOrigin.waste && cardCount > 2) {
      cardCount = 2;
    } else if (cardCount > 3) {
      cardCount = 3;
    }
    return CardStackPainter(_wastePile.sublist(_wastePile.length - cardCount));
  }

  /// gets the painter for the stock pile, if it exists
  CardPainter? get stockPainter {
    if (_stockPile.isEmpty) {
      return null;
    }
    return CardPainter(null);
  }

  /// checks the hand contains cards
  bool get handOccupied => _hand != null;

  /// gets the painter for the hand if it exists
  HandStackPainter? handPainter(Offset position) {
    if (_hand == null) {
      return null;
    }
    return HandStackPainter(cards: _hand!.$1.cards, position: position);
  }

  /// gets the interactable painters for the river stacks, with the given drag handlers
  InteractableCardStack riverStackInteractable(
    int index, {
    Key? key,
    required void Function(DragStartDetails, int) onDragStarted,
    required void Function(DragUpdateDetails) onDragUpdated,
    required void Function(DragEndDetails) onDragEnded,
  }) {
    return InteractableCardStack(
      key: key,
      cards: _riverStacks[index].cards,
      onDragStarted: onDragStarted,
      onDragUpdated: onDragUpdated,
      onDragEnded: onDragEnded,
    );
  }

  PlayerState({
    required List<RiverCardStack> riverStacks,
    required List<PlayingCard> stockPile,
    required List<PlayingCard> wastePile,
    required List<PlayingCard> nertzPile,
  }) : _nertzPile = nertzPile,
       _wastePile = wastePile,
       _stockPile = stockPile,
       _riverStacks = riverStacks {
    assert(riverStacks.length == 4);
  }

  static PlayerState newRandom() {
    List<PlayingCard> deck = PlayingCard.makeDeck()..shuffle();
    return PlayerState(
      riverStacks: [
        RiverCardStack(cards: [deck[0]]),
        RiverCardStack(cards: [deck[1]]),
        RiverCardStack(cards: [deck[2]]),
        RiverCardStack(cards: [deck[3]]),
      ],
      nertzPile: deck.sublist(4, 4 + 13),
      stockPile: deck.sublist(4 + 13),
      wastePile: [],
    );
  }

  /// gets the suit of the bottom card in the player's hand, if it exists
  CardSuit? get handBottomSuit {
    if (_hand == null) {
      return null;
    }
    return _hand!.$1.cards.first.suit;
  }

  /// gets the size of the player's hand
  int get handSize {
    if (_hand == null) {
      return 0;
    }
    return _hand!.$1.cards.length;
  }

  void _feedWaste() {
    for (int i = 0; i < 3; i++) {
      if (_stockPile.isEmpty) {
        break;
      }
      _wastePile.add(_stockPile.removeLast());
    }
  }

  void _resetStock() {
    _stockPile.addAll(_wastePile.reversed);
    _wastePile.clear();
  }

  void _rotateStock() {
    assert(_wastePile.isEmpty);
    _stockPile.add(_stockPile.removeAt(0));
  }

  void _returnHandToOrigin() {
    if (_hand == null) {
      return;
    }
    switch (_hand!.$2) {
      case HandOrigin.river1:
      case HandOrigin.river2:
      case HandOrigin.river3:
      case HandOrigin.river4:
        assert(
          _riverStacks[_hand!.$2.riverIndex].append(_hand!.$1),
          "hand cards could not be returned to river successfully",
        );
        break;
      case HandOrigin.waste:
        assert(
          _hand!.$1.cards.length == 1,
          "hand from waste should only have one card",
        );
        _wastePile.add(_hand!.$1.cards[0]);
        break;
      case HandOrigin.nertz:
        assert(
          _hand!.$1.cards.length == 1,
          "hand from nertz should only have one card",
        );
        _showNertzTopCard = true;
        _nertzPile.add(_hand!.$1.cards[0]);
        break;
    }
    _hand = null;
  }

  /// call this function to empty the hand
  /// only call this after hand contents have been copied to their destination
  void _emptyHand() {
    assert(_hand != null, "hand should be non-empty");
    if (_hand!.$2 == HandOrigin.nertz) {
      _showNertzTopCard = true;
    }
    if (_nertzPile.isEmpty) {
      throw UnimplementedError(
        "player has won, but win condition handling is not implemented",
      );
    }
    _hand = null;
    return;
  }

  /// handles a command to move cards in the player's state
  /// returns true if the command was executed successfully
  bool handleCommand(PlayerCommand command) {
    if (command.needsClearHand && _hand != null) {
      return false;
    }

    switch (command) {
      case RiverToHandCommand _:
        RiverCardStack stack = _riverStacks[command.riverIndex];
        if (command.splitIndex >= stack.cards.length) {
          return false;
        }
        _hand = (
          stack.splitAt(command.splitIndex),
          HandOrigin.values[command.riverIndex],
          const Offset(0, 0),
        );
        break;
      case WasteToHandCommand _:
        if (_wastePile.isEmpty) {
          return false;
        }
        _hand = (
          RiverCardStack(cards: [_wastePile.removeLast()]),
          HandOrigin.waste,
          const Offset(0, 0),
        );
        break;
      case NertzToHandCommand _:
        if (_nertzPile.isEmpty) {
          return false;
        }
        _hand = (
          RiverCardStack(cards: [_nertzPile.removeLast()]),
          HandOrigin.nertz,
          const Offset(0, 0),
        );
        _showNertzTopCard = false;
        break;
      case HandToRiverCommand _:
        if (_hand == null) {
          return false;
        }
        if (!_riverStacks[command.riverIndex].append(_hand!.$1)) {
          _returnHandToOrigin();
          return false;
        }
        _emptyHand();
        break;
      case CancelHandCommand _:
        if (_hand == null) {
          return false;
        }
        _returnHandToOrigin();
        break;
      case FeedWasteCommand _:
        _feedWaste();
        break;
      case ResetStockCommand _:
        _resetStock();
        break;
      case RotateStockCommand _:
        if (_wastePile.isNotEmpty) {
          return false;
        }
        _rotateStock();
        break;
    }

    print("Handled command: $command successfully");

    return true;
  }
}

/// the data for the lake
class LakeData {
  final List<PlayingCard?> spades;
  final List<PlayingCard?> hearts;
  final List<PlayingCard?> clubs;
  final List<PlayingCard?> diamonds;

  int get size => spades.length;

  LakeData({
    required this.spades,
    required this.hearts,
    required this.clubs,
    required this.diamonds,
  }) : assert(
         spades.length == hearts.length &&
             hearts.length == clubs.length &&
             clubs.length == diamonds.length,
       );

  LakeData.withSize(int size)
    : spades = List.filled(size, null),
      hearts = List.filled(size, null),
      clubs = List.filled(size, null),
      diamonds = List.filled(size, null);

  void clear() {
    for (int i = 0; i < size; i++) {
      spades[i] = null;
      hearts[i] = null;
      clubs[i] = null;
      diamonds[i] = null;
    }
  }

  List<PlayingCard?> getSuitList(CardSuit suit) {
    switch (suit) {
      case CardSuit.spades:
        return spades;
      case CardSuit.hearts:
        return hearts;
      case CardSuit.clubs:
        return clubs;
      case CardSuit.diamonds:
        return diamonds;
    }
  }

  /// check if the given card can be placed in the given stack in the lake
  /// automatically determines which suit list to check based on the card's suit
  bool canPlace(PlayingCard card, int index) {
    if (index >= size) {
      return false;
    }
    late final List<PlayingCard?> suitList;
    switch (card.suit) {
      case CardSuit.spades:
        suitList = spades;
        break;
      case CardSuit.hearts:
        suitList = hearts;
        break;
      case CardSuit.clubs:
        suitList = clubs;
        break;
      case CardSuit.diamonds:
        suitList = diamonds;
        break;
    }
    if (suitList[index] == null) {
      return card.value == CardValue.ace;
    }
    return card.lakeCanPlaceOn(suitList[index]!);
  }

  /// places a card in the lake, only failing if the index is out of bounds
  bool forcePlaceCard(PlayingCard card, int index) {
    if (index >= size) {
      return false;
    }
    late final List<PlayingCard?> suitList;
    switch (card.suit) {
      case CardSuit.spades:
        suitList = spades;
        break;
      case CardSuit.hearts:
        suitList = hearts;
        break;
      case CardSuit.clubs:
        suitList = clubs;
        break;
      case CardSuit.diamonds:
        suitList = diamonds;
        break;
    }
    suitList[index] = card;
    return true;
  }

  /// places the card in the lake if possible, returning true if successful
  bool placeCard(PlayingCard card, int index) {
    if (!canPlace(card, index)) {
      return false;
    }
    forcePlaceCard(card, index);
    return true;
  }
}
