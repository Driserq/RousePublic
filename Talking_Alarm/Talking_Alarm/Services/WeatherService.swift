import Foundation

class WeatherService {
    static let shared = WeatherService()
    
    private init() {}
    
    func getCurrentWeather() async -> String {
        // Placeholder implementation
        // In a real app, you would use WeatherKit here
        let weatherDescriptions = [
            "it's a beautiful day",
            "it's sunny and bright",
            "it's a perfect morning",
            "the weather is lovely",
            "it's a great day to start"
        ]
        
        // Return a random weather description for now
        return weatherDescriptions.randomElement() ?? "it's a beautiful day"
    }
}



