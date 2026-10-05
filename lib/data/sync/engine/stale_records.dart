final class StaleRecords {
  const StaleRecords({
    this.unpulled = const <int>{},
    this.pulled = const <int>{},
    this.unrepaired = const <int>{},
    this.rounds = 0,
    this.heldUntil,
  });

  final Set<int> unpulled;
  final Set<int> pulled;
  final Set<int> unrepaired;
  final int rounds;
  final DateTime? heldUntil;

  Set<int> heldAt(DateTime now) {
    final DateTime? until = heldUntil;
    return until != null && now.isBefore(until) ? unrepaired : const <int>{};
  }

  Set<int> answeredAgain(Set<int> stale) => stale.intersection(pulled);

  StaleRecords afterCompletePull() =>
      _copy(unpulled: const <int>{}, pulled: <int>{...pulled, ...unpulled});

  StaleRecords afterAnswer({required Set<int> sent, required Set<int> stale}) {
    final Set<int> settled = sent.difference(stale);
    return _copy(
      unpulled: <int>{...unpulled.difference(settled), ...stale},
      pulled: pulled.difference(sent),
      unrepaired: <int>{
        ...unrepaired.difference(settled),
        ...answeredAgain(stale),
      },
    );
  }

  StaleRecords within(Set<int> outbox) => _copy(
    unpulled: unpulled.intersection(outbox),
    pulled: pulled.intersection(outbox),
    unrepaired: unrepaired.intersection(outbox),
  );

  StaleRecords heldTill(DateTime until) =>
      _copy(rounds: rounds + 1, heldUntil: until);

  StaleRecords releasedWhenRepaired() => unrepaired.isEmpty
      ? StaleRecords(unpulled: unpulled, pulled: pulled)
      : this;

  StaleRecords _copy({
    Set<int>? unpulled,
    Set<int>? pulled,
    Set<int>? unrepaired,
    int? rounds,
    DateTime? heldUntil,
  }) => StaleRecords(
    unpulled: Set<int>.unmodifiable(unpulled ?? this.unpulled),
    pulled: Set<int>.unmodifiable(pulled ?? this.pulled),
    unrepaired: Set<int>.unmodifiable(unrepaired ?? this.unrepaired),
    rounds: rounds ?? this.rounds,
    heldUntil: heldUntil ?? this.heldUntil,
  );
}
