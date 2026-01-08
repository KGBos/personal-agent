import Foundation
import CoreLocation

/// Service for fetching weather data using Open-Meteo API (free, no key required)
actor WeatherService {
    private let geocoder = CLGeocoder()

    // MARK: - Public Methods

    func getWeather(for location: String) async throws -> WeatherData {
        // First, geocode the location to get coordinates
        let coordinates = try await geocodeLocation(location)

        // Fetch weather from Open-Meteo
        let weather = try await fetchWeather(latitude: coordinates.latitude, longitude: coordinates.longitude)

        return weather
    }

    func getWeatherByCoordinates(latitude: Double, longitude: Double) async throws -> WeatherData {
        return try await fetchWeather(latitude: latitude, longitude: longitude)
    }

    // MARK: - Private Methods

    private func geocodeLocation(_ location: String) async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: ToolError.executionFailed("Could not find location: \(error.localizedDescription)"))
                    return
                }

                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    continuation.resume(throwing: ToolError.notFound("Location not found: \(location)"))
                    return
                }

                continuation.resume(returning: location.coordinate)
            }
        }
    }

    private func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        // Open-Meteo API endpoint
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]

        guard let url = components.url else {
            throw ToolError.executionFailed("Failed to construct weather API URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ToolError.executionFailed("Weather API request failed")
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OpenMeteoResponse.self, from: data)

        return WeatherData(from: apiResponse)
    }
}

// MARK: - Data Models

struct WeatherData {
    let current: CurrentWeather
    let forecast: [DailyForecast]
    let timezone: String

    init(from response: OpenMeteoResponse) {
        self.timezone = response.timezone

        self.current = CurrentWeather(
            temperature: response.current.temperature_2m,
            apparentTemperature: response.current.apparent_temperature,
            humidity: response.current.relative_humidity_2m,
            precipitation: response.current.precipitation,
            windSpeed: response.current.wind_speed_10m,
            windDirection: response.current.wind_direction_10m,
            weatherCode: response.current.weather_code
        )

        self.forecast = zip(response.daily.time, zip(
            zip(response.daily.temperature_2m_max, response.daily.temperature_2m_min),
            zip(zip(response.daily.weather_code, response.daily.precipitation_sum), response.daily.precipitation_probability_max)
        )).map { (date, temps) in
            let ((maxTemp, minTemp), ((code, precip), precipProb)) = temps
            return DailyForecast(
                date: date,
                maxTemperature: maxTemp,
                minTemperature: minTemp,
                precipitationSum: precip,
                precipitationProbability: precipProb,
                weatherCode: code
            )
        }
    }
}

struct CurrentWeather {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let precipitation: Double
    let windSpeed: Double
    let windDirection: Int
    let weatherCode: Int

    var conditionDescription: String {
        weatherCodeToDescription(weatherCode)
    }

    var conditionEmoji: String {
        weatherCodeToEmoji(weatherCode)
    }
}

struct DailyForecast {
    let date: String
    let maxTemperature: Double
    let minTemperature: Double
    let precipitationSum: Double
    let precipitationProbability: Int
    let weatherCode: Int

    var conditionDescription: String {
        weatherCodeToDescription(weatherCode)
    }

    var conditionEmoji: String {
        weatherCodeToEmoji(weatherCode)
    }
}

// MARK: - Open-Meteo API Response

struct OpenMeteoResponse: Codable {
    let timezone: String
    let current: CurrentResponse
    let daily: DailyResponse

    struct CurrentResponse: Codable {
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let apparent_temperature: Double
        let precipitation: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Int
    }

    struct DailyResponse: Codable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_sum: [Double]
        let precipitation_probability_max: [Int]
    }
}

// MARK: - Weather Code Helpers

private func weatherCodeToDescription(_ code: Int) -> String {
    switch code {
    case 0: return "Clear sky"
    case 1: return "Mainly clear"
    case 2: return "Partly cloudy"
    case 3: return "Overcast"
    case 45, 48: return "Foggy"
    case 51, 53, 55: return "Drizzle"
    case 56, 57: return "Freezing drizzle"
    case 61, 63, 65: return "Rain"
    case 66, 67: return "Freezing rain"
    case 71, 73, 75: return "Snow"
    case 77: return "Snow grains"
    case 80, 81, 82: return "Rain showers"
    case 85, 86: return "Snow showers"
    case 95: return "Thunderstorm"
    case 96, 99: return "Thunderstorm with hail"
    default: return "Unknown"
    }
}

private func weatherCodeToEmoji(_ code: Int) -> String {
    switch code {
    case 0: return "☀️"
    case 1: return "🌤️"
    case 2: return "⛅"
    case 3: return "☁️"
    case 45, 48: return "🌫️"
    case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "🌧️"
    case 56, 57, 66, 67: return "🌨️"
    case 71, 73, 75, 77, 85, 86: return "❄️"
    case 95, 96, 99: return "⛈️"
    default: return "🌡️"
    }
}
