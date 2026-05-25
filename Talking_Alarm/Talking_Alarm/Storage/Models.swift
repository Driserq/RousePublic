import Foundation

struct User: Codable, Identifiable {
	var id: String { user_id }
	let user_id: String
	let email: String?
	let primary_goal: String?
	let preferred_wake_time: String?
}

struct Goal: Codable, Identifiable {
	var id: String { goal_id }
	let goal_id: String
	let user_id: String
	let description: String
	let is_active: Bool
}

struct VerificationLog: Codable, Identifiable {
	var id: String { log_id }
	let log_id: String
	let user_id: String
	let alarm_time: String
	let result: String
	let current_attempt: Int
	let confidence_score: Double
}


