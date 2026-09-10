import 'dart:async';

class CallDurationTimer {
  Timer? _timer;
  int _seconds = 0;
  final void Function(int seconds) onTick;

  CallDurationTimer({required this.onTick});

  int get currentSeconds => _seconds;

  void start() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds++;
      onTick(_seconds);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    _seconds = 0;
    _timer?.cancel();
    _timer = null;
  }
}
