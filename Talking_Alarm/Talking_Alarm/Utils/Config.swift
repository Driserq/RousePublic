import Foundation

struct AppConfig {
	static let shared = AppConfig()

	let openAIKey: String
	let elevenLabsKey: String
	let assemblyAIKey: String
	let supabaseURL: String
	let supabaseAnonKey: String
	let backendBaseURL: String
	let backendSharedKey: String

	private init() {
		let env = ProcessInfo.processInfo.environment
		var values: [String: String] = [
			"OPENAI_API_KEY": env["OPENAI_API_KEY"] ?? "",
			"ELEVENLABS_API_KEY": env["ELEVENLABS_API_KEY"] ?? "",
			"ASSEMBLYAI_API_KEY": env["ASSEMBLYAI_API_KEY"] ?? "",
			"SUPABASE_URL": env["SUPABASE_URL"] ?? "",
			"SUPABASE_ANON_KEY": env["SUPABASE_ANON_KEY"] ?? "",
			"BACKEND_BASE_URL": env["BACKEND_BASE_URL"] ?? "http://localhost:3000",
			"BACKEND_SHARED_KEY": env["BACKEND_SHARED_KEY"] ?? "ta-dev-shared-key"
		]
		if let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
		   let data = try? Data(contentsOf: url),
		   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
			for (k, v) in plist {
				if let s = v as? String, !s.isEmpty { values[k] = s }
			}
		}
		openAIKey = values["OPENAI_API_KEY"] ?? ""
		elevenLabsKey = values["ELEVENLABS_API_KEY"] ?? ""
		assemblyAIKey = values["ASSEMBLYAI_API_KEY"] ?? ""
		supabaseURL = values["SUPABASE_URL"] ?? ""
		supabaseAnonKey = values["SUPABASE_ANON_KEY"] ?? ""
		backendBaseURL = values["BACKEND_BASE_URL"] ?? "http://localhost:3000"
		backendSharedKey = values["BACKEND_SHARED_KEY"] ?? "ta-dev-shared-key"
	}

	var hasAIKeys: Bool { !openAIKey.isEmpty && !elevenLabsKey.isEmpty && !assemblyAIKey.isEmpty }
}


