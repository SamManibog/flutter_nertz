import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_nertz/nertz.dart';

class HalfCardPainter extends CustomPainter {
  static const Size size = Size(60, 30);
  static const double pipFontSize = CardPainter.pipFontSize;
  static const Offset pipOffset = CardPainter.pipOffset;
  static const double cornerRadius = CardPainter.cornerRadius;

  static const Color backgroundColor = CardPainter.backgroundColor;
  static const Color blackColor = CardPainter.blackColor;
  static const Color redColor = CardPainter.redColor;

  final PlayingCard card;

  const HalfCardPainter(this.card);

  static Color getColor(CardColor color) {
    switch (color) {
      case .red:
        return redColor;
      case .black:
        return blackColor;
    }
  }

  static void paintPositioned(
    Canvas canvas,
    Offset position,
    PlayingCard card,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    // the rectangle for the background and border of the card
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topLeft: Radius.circular(cornerRadius),
      topRight: Radius.circular(cornerRadius),
    );

    // paint the background
    var bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, bgPaint);

    // paint pip
    final pipText = "${card.suit.unicode} ${card.value.pipText}";
    TextPainter pipPainter = TextPainter(
      text: TextSpan(
        text: pipText,
        style: TextStyle(
          color: getColor(card.suit.color),
          fontSize: pipFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    pipPainter.layout();
    pipPainter.paint(canvas, Offset(pipOffset.dx, pipOffset.dy));

    // paint the border
    var borderPaint = Paint()
      ..color = blackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rect, borderPaint);

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    HalfCardPainter.paintPositioned(canvas, Offset.zero, card);
  }

  @override
  bool shouldRepaint(HalfCardPainter oldDelegate) {
    return oldDelegate.card != card;
  }
}

class CardPainter extends CustomPainter {
  static const Size size = Size(60, 80);
  static const double cornerRadius = 6;
  static const double backInset = 4;
  static const double pipFontSize = 14;
  static const double centerFontSize = 20;
  static const double lineSpacing = 1.05;
  static const Offset pipOffset = Offset(4, 5);

  static const Color backgroundColor = Color.fromARGB(255, 248, 247, 247);
  static const Color backColor = Color.fromARGB(255, 50, 96, 152);
  static const Color blackColor = Color.fromARGB(255, 28, 15, 15);
  static const Color redColor = Color.fromARGB(255, 159, 17, 17);

  final PlayingCard? card;

  const CardPainter(this.card);

  static Color getColor(CardColor color) {
    switch (color) {
      case .red:
        return redColor;
      case .black:
        return blackColor;
    }
  }

  static void _paintPip(Canvas canvas, Offset position, PlayingCard type) {
    final pipText = "${type.value.pipText}\n${type.suit.unicode}";
    //final pipText = "${type.suit.unicode} ${type.value.pipText}";
    TextPainter pipPainter = TextPainter(
      text: TextSpan(
        text: pipText,
        style: TextStyle(
          color: getColor(type.suit.color),
          fontSize: pipFontSize,
          fontWeight: FontWeight.bold,
          height: lineSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    pipPainter.layout();
    pipPainter.paint(
      canvas,
      Offset(pipOffset.dx, pipOffset.dy + pipFontSize * (1.0 - lineSpacing)),
    );
  }

  /// paints a playing card at the given position
  /// if card is null, paints the back of the card
  static void paintPositioned(
    Canvas canvas,
    Offset position,
    PlayingCard? card,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    // the rectangle for the background and border of the card
    var rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(cornerRadius),
    );

    // paint the background
    var bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, bgPaint);

    if (card == null) {
      // paint the back of the card
      var faceDownPaint = Paint()
        ..color = backColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect.deflate(backInset), faceDownPaint);
    } else {
      // paint pip
      canvas.save();
      canvas.translate(size.width, size.height);
      canvas.rotate(pi);
      CardPainter._paintPip(canvas, position, card);
      canvas.restore();
      CardPainter._paintPip(canvas, position, card);

      /*/ print suit in the middle of the card
      TextPainter suitPainter = TextPainter(
        text: TextSpan(
          text: card.suit.unicode,
          style: TextStyle(
            color: getColor(card.suit.color),
            fontSize: centerFontSize,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      suitPainter.layout();
      suitPainter.paint(
        canvas,
        Offset(
          (size.width - suitPainter.width) / 2,
          (size.height - suitPainter.height) / 2,
        ),
      );
      */
    }

    // paint the border
    var borderPaint = Paint()
      ..color = blackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rect, borderPaint);

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    CardPainter.paintPositioned(canvas, Offset.zero, card);
  }

  @override
  bool shouldRepaint(CardPainter oldDelegate) {
    return oldDelegate.card != card;
  }
}

class CardStackPainter extends CustomPainter {
  static const double offsetY = 30;

  final List<PlayingCard> cards;

  const CardStackPainter(this.cards);

  /// calculates the minimum size needed to paint a stack of cards with the given number of cards
  static Size calculateSize(int numCards) {
    return Size(
      CardPainter.size.width,
      CardPainter.size.height + offsetY * (numCards - 1),
    );
  }

  /// paints a stack of cards at the given position, with the given list of cards
  static void paintPositioned(
    Canvas canvas,
    Offset position,
    List<PlayingCard> cards,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    for (int i = 0; i < cards.length; i++) {
      CardPainter.paintPositioned(canvas, Offset(0, i * offsetY), cards[i]);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintPositioned(canvas, Offset.zero, cards);
  }

  @override
  bool shouldRepaint(CardStackPainter oldDelegate) {
    if (oldDelegate.cards.length != cards.length) {
      return true;
    }
    for (int i = 0; i < cards.length; i++) {
      if (oldDelegate.cards[i] != cards[i]) {
        return true;
      }
    }
    return false;
  }
}

class InteractableCardStack extends StatelessWidget {
  final List<PlayingCard> cards;
  final void Function(DragStartDetails, int) onDragStarted;
  final void Function(DragUpdateDetails) onDragUpdated;
  final void Function(DragEndDetails) onDragEnded;

  const InteractableCardStack({
    super.key,
    required this.cards,
    required this.onDragStarted,
    required this.onDragUpdated,
    required this.onDragEnded,
  });

  /// calculates the index of the card being dragged based on the position of the drag start
  /// assumes that the drag starts within the bounds of the card stack
  int _calculateDragIndex(DragStartDetails details) {
    // the size of the clickable area of covered cards
    final coveredSize = Size(CardPainter.size.width, CardStackPainter.offsetY);

    final localPosition = details.localPosition;

    // check covered cards
    for (int i = 0; i < cards.length - 1; i++) {
      final cardRect = Rect.fromLTWH(
        0,
        i * CardStackPainter.offsetY,
        coveredSize.width,
        coveredSize.height,
      );
      if (cardRect.contains(localPosition)) {
        return i;
      }
    }

    // if not on a covered card, must be on the top card
    return cards.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) =>
          onDragStarted(details, _calculateDragIndex(details)),
      onVerticalDragStart: (details) =>
          onDragStarted(details, _calculateDragIndex(details)),
      onHorizontalDragUpdate: onDragUpdated,
      onVerticalDragUpdate: onDragUpdated,
      onHorizontalDragEnd: onDragEnded,
      onVerticalDragEnd: onDragEnded,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        size: CardStackPainter.calculateSize(cards.length),
        painter: CardStackPainter(cards),
      ),
    );
  }
}

class _HandStackPainterInternal extends CustomPainter {
  final Offset position;
  final List<PlayingCard> cards;

  const _HandStackPainterInternal({required this.position, required this.cards});

  @override
  void paint(Canvas canvas, Size size) {
    CardStackPainter.paintPositioned(canvas, position, cards);
  }

  @override
  bool shouldRepaint(_HandStackPainterInternal oldDelegate) {
    return true;
  }
}

/// a sizeless stack painter that paints a stack of cards at the given position
class HandStackPainter extends StatelessWidget {
  final Offset position;
  final List<PlayingCard> cards;

  const HandStackPainter({super.key, required this.position, required this.cards});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.zero,
      painter: _HandStackPainterInternal(position: position, cards: cards),
    );
  }
}
