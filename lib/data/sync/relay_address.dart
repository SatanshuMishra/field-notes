const int relayAddressMaxLength = 128;
const int _maxLabelLength = 63;

bool isUsableRelayAddress(Uri address) =>
    (address.scheme == 'https' || address.scheme == 'http') &&
    address.toString().length <= relayAddressMaxLength &&
    address.host.isNotEmpty &&
    !address.host.contains('%') &&
    address.host
        .split('.')
        .every((String label) => label.length <= _maxLabelLength) &&
    address.userInfo.isEmpty &&
    !address.hasQuery &&
    !address.hasFragment;
