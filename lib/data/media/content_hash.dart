import 'package:crypto/crypto.dart';

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

Future<String> sha256HexOfStream(Stream<List<int>> stream) async {
  final digest = await sha256.bind(stream).first;
  return digest.toString();
}
