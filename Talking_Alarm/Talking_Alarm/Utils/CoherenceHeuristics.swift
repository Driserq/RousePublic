import Foundation

enum CoherenceHeuristics {
    struct Result {
        let lengthScore: Double
        let fillerPenalty: Double
        let goalMentionBonus: Double
        let total: Double
    }

    static func analyze(transcript: String, goal: String) -> Result {
        let words = transcript.split(separator: " ")
        let lengthScore = min(1.0, Double(words.count) / 20.0)

        let fillers = ["um", "uh", "like", "you know", "kinda", "sorta"]
        let fillerCount = fillers.reduce(0) { count, filler in
            count + transcript.lowercased().components(separatedBy: filler).count - 1
        }
        let fillerPenalty = min(0.5, Double(fillerCount) * 0.05)

        let goalMention = transcript.lowercased().contains(goal.lowercased())
        let goalMentionBonus = goalMention ? 0.2 : 0.0

        let total = max(0.0, min(1.0, lengthScore - fillerPenalty + goalMentionBonus))
        return Result(lengthScore: lengthScore, fillerPenalty: fillerPenalty, goalMentionBonus: goalMentionBonus, total: total)
    }
}


