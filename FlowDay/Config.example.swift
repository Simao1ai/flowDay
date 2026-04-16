// Config.example.swift
// FlowDay
//
// Copy this file to Config.swift (already gitignored) and fill in real values.
// See SETUP.md for step-by-step instructions.
//
// NEVER commit Config.swift — it contains your Supabase project credentials.

import Foundation

enum FlowDayConfig {
    /// Your Supabase project URL, e.g. "https://xxxxxxxxxxxx.supabase.co"
    static let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"

    /// Your Supabase anon (public) key — safe to ship, enforced by Row Level Security
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
}
