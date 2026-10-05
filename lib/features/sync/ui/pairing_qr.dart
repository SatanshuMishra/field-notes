import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

const String pairingQrLabel = 'Code to scan with your other device';

const double _quietZone = 12;

class PairingQr extends StatelessWidget {
  const PairingQr({super.key, required this.payload, this.size = 200});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors scannable = FieldNotesColors.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scannable.cardBright,
        border: context.shadows.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: QrImageView(
        data: payload,
        size: size,
        padding: const EdgeInsets.all(_quietZone),
        backgroundColor: scannable.cardBright,
        semanticsLabel: pairingQrLabel,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: scannable.ink),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: scannable.ink,
        ),
      ),
    );
  }
}
