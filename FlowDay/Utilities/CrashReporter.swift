// CrashReporter.swift
// FlowDay
//
// Thin wrapper around Firebase Crashlytics. All crash/error reporting in the
// app goes through this type so we can swap the backend without touching call sites.

import Foundation
import FirebaseCrashlytics

enum CrashReporter {

    /// Log a plain message (visible in Crashlytics session logs).
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Record a non-fatal error with optional context tag.
    static func record(_ error: Error, context: String? = nil) {
        if let context {
            Crashlytics.crashlytics().log("[\(context)] \(error.localizedDescription)")
        }
        Crashlytics.crashlytics().record(error: error)
    }

    /// Associate the current session with a user ID (first 8 chars only for privacy).
    static func setUser(_ userId: String) {
        Crashlytics.crashlytics().setUserID(String(userId.prefix(8)))
    }
}
