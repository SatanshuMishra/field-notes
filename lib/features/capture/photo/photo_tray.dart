import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:flutter/widgets.dart';

import 'photo_picker.dart';
import 'photo_thumbnail.dart';

const int defaultMaxPhotos = 8;

class PhotoTray extends StatefulWidget {
  const PhotoTray({
    super.key,
    required this.picker,
    required this.onChanged,
    this.initialPhotos = const <CaptureMedia>[],
    this.maxPhotos = defaultMaxPhotos,
    this.libraryLabel = 'Add from library',
    this.cameraLabel = 'Take a photo',
  });

  final PhotoPicker picker;
  final ValueChanged<List<CaptureMedia>> onChanged;
  final List<CaptureMedia> initialPhotos;
  final int maxPhotos;
  final String libraryLabel;
  final String cameraLabel;

  @override
  State<PhotoTray> createState() => _PhotoTrayState();
}

class _PhotoTrayState extends State<PhotoTray> {
  late List<CaptureMedia> _photos;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _photos = List<CaptureMedia>.of(widget.initialPhotos);
  }

  bool get _canAdd => _photos.length < widget.maxPhotos;

  void _emit() => widget.onChanged(List<CaptureMedia>.unmodifiable(_photos));

  Future<void> _addFromLibrary() async {
    _clearError();
    try {
      final List<CaptureMedia> picked = await widget.picker.pickFromLibrary();
      if (!mounted || picked.isEmpty) {
        return;
      }
      _append(picked);
    } on PhotoPickException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _captureFromCamera() async {
    _clearError();
    try {
      final CaptureMedia? photo = await widget.picker.captureFromCamera();
      if (!mounted || photo == null) {
        return;
      }
      _append(<CaptureMedia>[photo]);
    } on PhotoPickException catch (error) {
      _showError(error.message);
    }
  }

  void _append(List<CaptureMedia> picked) {
    final int remaining = widget.maxPhotos - _photos.length;
    if (remaining <= 0) {
      return;
    }
    setState(() {
      _photos = <CaptureMedia>[..._photos, ...picked.take(remaining)];
    });
    _emit();
  }

  void _removeAt(int index) {
    setState(() {
      _photos = <CaptureMedia>[
        for (int i = 0; i < _photos.length; i++)
          if (i != index) _photos[i],
      ];
    });
    _emit();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = _errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_photos.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < _photos.length; i++)
                _PhotoTrayTile(
                  media: _photos[i],
                  index: i,
                  onRemove: () => _removeAt(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            StickerButton(
              label: widget.libraryLabel,
              variant: StickerButtonVariant.secondary,
              onPressed: _canAdd ? _addFromLibrary : null,
            ),
            if (widget.picker.supportsCamera)
              StickerButton(
                label: widget.cameraLabel,
                variant: StickerButtonVariant.secondary,
                onPressed: _canAdd ? _captureFromCamera : null,
              ),
          ],
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
          ),
        ],
      ],
    );
  }
}

class _PhotoTrayTile extends StatelessWidget {
  const _PhotoTrayTile({
    required this.media,
    required this.index,
    required this.onRemove,
  });

  final CaptureMedia media;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        PhotoThumbnail(media: media),
        Positioned(
          top: 2,
          right: 2,
          child: Semantics(
            button: true,
            label: 'Remove photo ${index + 1}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.cardBright,
                  border: Shapes.outline,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ExcludeSemantics(
                    child: Text(
                      '×',
                      style: TypographyTokens.buttonSans
                          .copyWith(color: Palette.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
