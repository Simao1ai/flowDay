// AppIconSettingsView.swift
// FlowDay

import SwiftUI

struct AppIconSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    currentIconPreview

                    comingSoonCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.fdBackground)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { FDSettingsUI.backButton { dismiss() } }
            }
        }
    }

    private var currentIconPreview: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.fdAccent, Color.fdAccentSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    ZStack {
                        Text("F")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .offset(x: 26, y: -26)
                    }
                )
                .shadow(color: Color.fdAccent.opacity(0.4), radius: 12, y: 6)

            Text("FlowDay")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)
            Text("Current icon")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var comingSoonCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.fdAccent)

            Text("More icons coming soon")
                .font(.fdBodySemibold)
                .foregroundStyle(Color.fdText)

            Text("We're designing a collection of beautiful alternate icons — Midnight, Ocean, Sunset, and more. They'll appear here when ready.")
                .font(.fdCaption)
                .foregroundStyle(Color.fdTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.fdAccentLight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.fdBorder, lineWidth: 1)
        )
    }
}
