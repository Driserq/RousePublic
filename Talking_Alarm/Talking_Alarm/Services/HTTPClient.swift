import Foundation

enum HTTPError: Error {
    case invalidURL
    case httpCode(Int)
    case decoding(Error)
    case transport(Error)
    case emptyData
}

final class HTTPClient {
    static let shared = HTTPClient()
    private init() {}

    func get<T: Decodable>(_ urlString: String, headers: [String: String] = [:]) async throws -> T {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpMethod = "GET"
        return try await execute(request)
    }

    func post<T: Decodable, U: Encodable>(_ urlString: String, body: U, headers: [String: String] = [:]) async throws -> T {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    func postRaw(_ urlString: String, body: Data, headers: [String: String] = [:]) async throws -> Data {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpMethod = "POST"
        request.httpBody = body
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw HTTPError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw HTTPError.emptyData }
        guard 200..<300 ~= http.statusCode else { throw HTTPError.httpCode(http.statusCode) }
        return data
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw HTTPError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw HTTPError.emptyData }
        guard 200..<300 ~= http.statusCode else { throw HTTPError.httpCode(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HTTPError.decoding(error)
        }
    }
}


