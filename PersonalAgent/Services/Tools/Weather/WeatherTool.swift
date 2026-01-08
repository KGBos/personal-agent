import Foundation

/// Tool for fetching current weather and forecast
struct WeatherTool: AgentTool {
    let name = "weather_get"
    let description = "Get current weather conditions and 7-day forecast for a location. Provide either a city name or coordinates."
    let requiresConfirmation = false // Read-only operation

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "location": .init(
                type: "string",
                description: "City name or address (e.g., 'San Francisco', 'New York, NY', 'Tokyo, Japan')",
                enumValues: nil,
                items: nil
            ),
            "latitude": .init(
                type: "number",
                description: "Latitude coordinate (optional, use instead of location)",
                enumValues: nil,
                items: nil
            ),
            "longitude": .init(
                type: "number",
                description: "Longitude coordinate (optional, use instead of location)",
                enumValues: nil,
                items: nil
            ),
            "units": .init(
                type: "string",
                description: "Temperature units: 'celsius' (default) or 'fahrenheit'",
                enumValues: ["celsius", "fahrenheit"],
                items: nil
            )
        ],
        required: nil // Either location or lat/lon required
    )

    private let weatherService = WeatherService()

    func execute(arguments: [String: Any]) async throws -> String {
        let units = (arguments["units"] as? String ?? "celsius").lowercased()
        let useFahrenheit = units == "fahrenheit"

        // Try to get weather by coordinates or location
        let weather: WeatherData

        if let latitude = arguments["latitude"] as? Double,
           let longitude = arguments["longitude"] as? Double {
            weather = try await weatherService.getWeatherByCoordinates(latitude: latitude, longitude: longitude)
        } else if let location = arguments["location"] as? String {
            weather = try await weatherService.getWeather(for: location)
        } else {
            throw ToolError.invalidArguments("Please provide either 'location' or both 'latitude' and 'longitude'")
        }

        return formatWeatherReport(weather, useFahrenheit: useFahrenheit)
    }

    // MARK: - Formatting

    private func formatWeatherReport(_ weather: WeatherData, useFahrenheit: Bool) -> String {
        var report = ""

        // Current conditions
        let current = weather.current
        let currentTemp = formatTemperature(current.temperature, useFahrenheit: useFahrenheit)
        let feelsLike = formatTemperature(current.apparentTemperature, useFahrenheit: useFahrenheit)

        report += "## Current Conditions\n\n"
        report += "\(current.conditionEmoji) \(current.conditionDescription)\n"
        report += "Temperature: \(currentTemp) (feels like \(feelsLike))\n"
        report += "Humidity: \(current.humidity)%\n"
        report += "Wind: \(current.windSpeed) km/h \(windDirectionName(current.windDirection))\n"

        if current.precipitation > 0 {
            report += "Precipitation: \(current.precipitation) mm\n"
        }

        // 7-day forecast
        report += "\n## 7-Day Forecast\n\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEE, MMM d"

        for day in weather.forecast {
            if let date = dateFormatter.date(from: day.date) {
                let dateStr = displayFormatter.string(from: date)
                let high = formatTemperature(day.maxTemperature, useFahrenheit: useFahrenheit)
                let low = formatTemperature(day.minTemperature, useFahrenheit: useFahrenheit)

                report += "\(day.conditionEmoji) \(dateStr): \(day.conditionDescription)\n"
                report += "   High: \(high) | Low: \(low)"

                if day.precipitationProbability > 0 {
                    report += " | Rain: \(day.precipitationProbability)%"
                }
                report += "\n"
            }
        }

        return report
    }

    private func formatTemperature(_ celsius: Double, useFahrenheit: Bool) -> String {
        if useFahrenheit {
            let fahrenheit = celsius * 9/5 + 32
            return String(format: "%.0f°F", fahrenheit)
        } else {
            return String(format: "%.0f°C", celsius)
        }
    }

    private func windDirectionName(_ degrees: Int) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(degrees) / 22.5).rounded()) % 16
        return directions[index]
    }
}
