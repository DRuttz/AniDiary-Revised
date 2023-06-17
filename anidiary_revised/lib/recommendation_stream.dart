import 'dart:async';

class RecommendationStream {
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static Stream<bool> get stream => _controller.stream;

  static void updateRecommendedAnime() {
    _controller.sink.add(true);
  }

  static void dispose() {
    _controller.close();
  }
}
