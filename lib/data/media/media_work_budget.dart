const Duration _mediaWorkFloor = Duration(seconds: 10);
const Duration _mediaWorkCap = Duration(seconds: 120);

Duration mediaWorkBudget(Duration take) {
  final Duration budget = _mediaWorkFloor + take ~/ 4;
  return budget > _mediaWorkCap ? _mediaWorkCap : budget;
}
