import 'package:flutter/material.dart';
import 'weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _service = WeatherService();
  Weather? _weather;
  bool _loading = false;
  String? _error;

  // Hardcode Vancouver
  final double _lat = 49.2827;
  final double _lon = -123.1207;

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final w = await _service.fetchWeather(
        latitude: _lat,
        longitude: _lon,
      );
      setState(() {
        _weather = w;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text('Error: $_error')
            : _weather == null
            ? const Text('No data')
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperature: ${_weather!.temperature.toStringAsFixed(1)} °C'),
            const SizedBox(height: 8),
            Text('Wind speed: ${_weather!.windSpeed.toStringAsFixed(1)} m/s'),
            const SizedBox(height: 8),
            Text('Condition: ${_weather!.condition}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWeather,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
