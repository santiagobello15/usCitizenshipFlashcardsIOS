import Foundation

enum ReviewManager {
    private static let lifetimeCorrectKey = "lifetimeCorrectCount"
    private static let sessionCountKey     = "sessionCount"
    private static let didRequestKey       = "didRequestReview"

    private static let lifetimeThreshold     = 15
    private static let minSessions           = 2
    private static let minCorrectThisSession = 3

    /// Correct answers in the current app run. Lives only for the process
    /// lifetime, so it resets to zero on every launch.
    private static var sessionCorrectCount = 0

    /// Call once per app launch. Resets the per-session counter and bumps
    /// the persistent session count.
    static func startSession() {
        sessionCorrectCount = 0
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: sessionCountKey) + 1, forKey: sessionCountKey)
    }

    /// Records a correct answer and reports whether this is the moment to
    /// ask for a review. Requires: enough lifetime correct answers, at least
    /// two sessions, and a minimum of correct answers within this session —
    /// so someone who opens the app sitting on the threshold and taps once
    /// is not prompted immediately. Fires at most once, ever.
    static func registerCorrectAnswer() -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didRequestKey) else { return false }

        let lifetime = defaults.integer(forKey: lifetimeCorrectKey) + 1
        defaults.set(lifetime, forKey: lifetimeCorrectKey)
        sessionCorrectCount += 1

        guard lifetime >= lifetimeThreshold,
              defaults.integer(forKey: sessionCountKey) >= minSessions,
              sessionCorrectCount >= minCorrectThisSession else { return false }

        defaults.set(true, forKey: didRequestKey)
        return true
    }
}
