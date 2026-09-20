import 'package:agora_rtc_engine/agora_rtc_engine.dart';

enum NetworkCallQuality {
  good,
  fair,
  poor,
  unknown;

  String get label {
    switch (this) {
      case NetworkCallQuality.good:
        return 'Good';
      case NetworkCallQuality.fair:
        return 'Fair';
      case NetworkCallQuality.poor:
        return 'Poor';
      case NetworkCallQuality.unknown:
        return 'Good';
    }
  }

  String get emoji {
    switch (this) {
      case NetworkCallQuality.good:
        return '🟢';
      case NetworkCallQuality.fair:
        return '🟡';
      case NetworkCallQuality.poor:
        return '🔴';
      case NetworkCallQuality.unknown:
        return '🟢';
    }
  }
}

class NetworkQualityService {
  /// Maps Agora RTC QualityType to Good / Fair / Poor.
  /// Excellent / Good (1, 2) -> Good
  /// Poor (3) -> Fair
  /// Bad / VBad / Down (4, 5, 6) -> Poor
  static NetworkCallQuality fromAgoraQuality(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
      case QualityType.qualityGood:
        return NetworkCallQuality.good;
      case QualityType.qualityPoor:
        return NetworkCallQuality.fair;
      case QualityType.qualityBad:
      case QualityType.qualityVbad:
      case QualityType.qualityDown:
        return NetworkCallQuality.poor;
      case QualityType.qualityUnknown:
      case QualityType.qualityUnsupported:
      case QualityType.qualityDetecting:
        return NetworkCallQuality.unknown;
    }
  }
}
