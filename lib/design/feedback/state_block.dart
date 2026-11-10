import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:flutter/widgets.dart';

import '../flowers/flower_bloom.dart';
import '../tokens/tokens.dart';
import '../widgets/sticker_button.dart';
import 'empty_state.dart';

const String stateBlockLoadingLabel = 'Loading';
const String stateBlockRetryLabel = 'Try again';

const EdgeInsets _blockPadding = EdgeInsets.symmetric(
  horizontal: Spacing.space12,
  vertical: 20,
);
const double _stackGap = 6;
const double _actionGap = 12;
const double _artExtent = 44;
const double _skeletonHeight = 20;
const double _shortSkeletonWidthFactor = 0.7;
const double _messageFontSize = 13;

enum _StateBlockKind { loading, empty, error }

class StateBlock extends StatelessWidget {
  const StateBlock.loading({super.key, this.message = stateBlockLoadingLabel})
    : _kind = _StateBlockKind.loading,
      title = null,
      art = null,
      actionLabel = null,
      onAction = null;

  const StateBlock.empty({
    super.key,
    required String this.title,
    required this.message,
    this.art,
    this.actionLabel,
    this.onAction,
  }) : _kind = _StateBlockKind.empty;

  const StateBlock.error({
    super.key,
    required String this.title,
    required this.message,
    required VoidCallback onRetry,
    String retryLabel = stateBlockRetryLabel,
    this.art,
  }) : _kind = _StateBlockKind.error,
       actionLabel = retryLabel,
       onAction = onRetry;

  final _StateBlockKind _kind;
  final String? title;
  final String message;
  final Widget? art;
  final String? actionLabel;
  final VoidCallback? onAction;

  TextStyle _messageStyle(BuildContext context) =>
      context.textStyles.caption.copyWith(fontSize: _messageFontSize);

  FlowerKind get _defaultFlower => _kind == _StateBlockKind.error
      ? FlowerKind.bleedingHeart
      : FlowerKind.daffodil;

  StickerButtonVariant get _actionVariant => _kind == _StateBlockKind.error
      ? StickerButtonVariant.secondary
      : StickerButtonVariant.primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: context.colors.ink35,
          radius: Shapes.radius16,
        ),
        child: Padding(
          padding: _blockPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _kind == _StateBlockKind.loading
                ? _loadingChildren(context)
                : _messageChildren(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _loadingChildren(BuildContext context) => <Widget>[
    const _SkeletonLine(),
    const SizedBox(height: _stackGap),
    const _SkeletonLine(),
    const SizedBox(height: _stackGap),
    const FractionallySizedBox(
      widthFactor: _shortSkeletonWidthFactor,
      child: _SkeletonLine(),
    ),
    const SizedBox(height: _actionGap),
    Semantics(
      liveRegion: true,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: _messageStyle(context),
      ),
    ),
  ];

  List<Widget> _messageChildren(BuildContext context) {
    final String? label = actionLabel;
    final VoidCallback? action = onAction;
    return <Widget>[
      ExcludeSemantics(
        child: art ?? FlowerBloom(kind: _defaultFlower, size: _artExtent),
      ),
      const SizedBox(height: _stackGap),
      Semantics(
        header: true,
        liveRegion: _kind == _StateBlockKind.error,
        child: Text(
          title!,
          textAlign: TextAlign.center,
          style: context.textStyles.heading,
        ),
      ),
      const SizedBox(height: _stackGap),
      Text(message, textAlign: TextAlign.center, style: _messageStyle(context)),
      if (label != null && action != null) ...<Widget>[
        const SizedBox(height: _actionGap),
        StickerButton(
          label: label,
          variant: _actionVariant,
          padTapTarget: true,
          onPressed: action,
        ),
      ],
    ];
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _skeletonHeight,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: context.colors.ink22,
          radius: Shapes.radius8,
        ),
      ),
    );
  }
}
