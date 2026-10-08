import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/features/sync/ui/qr_frame_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final String _pairing = PairingCode(
  secret: List<int>.filled(pairingSecretBytes, 3),
  relayUrl: Uri.parse('https://relay.example'),
).qrPayload;

void main() {
  test('a camera frame is decoded as BGRA with its row stride', () {
    final DecodeParams params = qrDecodeParamsFor(
      width: 1280,
      height: 720,
      bytesPerRow: 5184,
    );

    expect(params.imageFormat, ImageFormat.bgra);
    expect(params.format, Format.qrCode);
    expect(params.width, 1296);
    expect(params.height, 720);
    expect(params.cropWidth, 1280);
    expect(params.cropHeight, 720);
    expect(params.tryHarder, isTrue);

    expect(pairingCodeFromScan(Code(text: _pairing, isValid: true)), _pairing);
    expect(
      pairingCodeFromScan(Code(text: 'https://relay.example', isValid: true)),
      isNull,
    );
    expect(
      pairingCodeFromScan(Code(text: 'fieldnotes:$_pairing', isValid: true)),
      isNull,
    );
    expect(pairingCodeFromScan(Code(text: _pairing)), isNull);
    expect(pairingCodeFromScan(Code(isValid: true)), isNull);
  });
}
