const int relayAddressMaxLength = 128;
const int _maxLabelLength = 63;

const Set<String> _loopbackHosts = <String>{'127.0.0.1', 'localhost', '::1'};

bool _isEncryptedOrLocal(Uri address) =>
    address.scheme == 'https' ||
    (address.scheme == 'http' && _loopbackHosts.contains(address.host));

bool isUsableRelayAddress(Uri address) =>
    _isEncryptedOrLocal(address) &&
    address.toString().length <= relayAddressMaxLength &&
    address.host.isNotEmpty &&
    !address.host.contains('%') &&
    address.host
        .split('.')
        .every((String label) => label.length <= _maxLabelLength) &&
    address.userInfo.isEmpty &&
    !address.hasQuery &&
    !address.hasFragment;
