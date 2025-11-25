import 'dart:convert';
import 'package:http/http.dart' as http;

// Model of the Weather
class Weather {
  final double temperature;  // current temperature（℃）
  final double windSpeed;    // wind speed（m/s）
  final String condition;    // sunny / cloudy / rainy / snowy / other

  Weather({
    required this.temperature,
    required this.windSpeed,
    required this.condition,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final temp = (current['temperature_2m'] as num).toDouble();
    final wind = (current['wind_speed_10m'] as num).toDouble();
    final int code =  (current['weather_code'] ?? current['weathercode']) as int;

    return Weather(
      temperature: temp,
      windSpeed: wind,
      condition: _simpleCondition(code),
    );
  }

  static String _simpleCondition(int code) {
    if (code == 0) return 'sunny';
    if (code == 1 || code == 2 || code == 3) return 'cloudy';
    if (code == 45 || code == 48) return 'cloudy';
    if (code >= 51 && code <= 67) return 'rainy';
    if (code >= 71 && code <= 86) return 'snowy';
    if (code >= 80 && code <= 82) return 'rainy';
    if (code >= 95 && code <= 99) return 'rainy';

    return 'other';
  }
}


class WeatherService {
   // request Open-Meteo
  Future<Weather> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
          '?latitude=$latitude'
          '&longitude=$longitude'
          '&current=temperature_2m,wind_speed_10m,weather_code',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load weather: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return Weather.fromJson(data);
  }
}


String lottieFor(String condition) {
  switch (condition) {
    case 'sunny':  return 'assets/lottie/sunny.json';
    case 'cloudy': return 'assets/lottie/cloudy.json';
    case 'rainy':  return 'assets/lottie/rain.json';
    case 'snowy':  return 'assets/lottie/snow.json';
    default:       return 'assets/lottie/cloudy.json';
  }
}


String weatherTip(String condition) {
  switch (condition) {
    case 'sunny':
      return "Nice sunny day ☀️";
    case 'cloudy':
      return "Cloudy but cozy ☁️";
    case 'rainy':
      return "Rainy day, stay dry 🌧";
    case 'snowy':
      return "Snowy outside ❄️";
    default:
      return "Have a lovely day 💜";
  }
}
