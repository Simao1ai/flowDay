// VoiceInputView.swift
// FlowDay
//
// Full-screen voice capture sheet for Flow AI. Streams speech via
// SpeechRecognizer and returns the transcribed text on send.

import SwiftUI

struct VoiceInputView: View {
    @Environment(\.dismiss) var dismiss
    @State private var speechRecognizer = SpeechRecognizer()
    var onSend: (String) -> Void

    var body: some View {
        ZStack {
            Color.fdBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)
                    }
                    Spacer()
                    Text("Voice Input")
                        .font(.fdTitle3)
                        .foregroundColor(.fdText)
                    Spacer()
                    Color.clear
                        .frame(width: 44)
                }
                .padding()

                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.fdAccent)
                            .frame(width: 120, height: 120)
                            .scaleEffect(speechRecognizer.isListening ? 1.2 : 1.0)
                            .opacity(speechRecognizer.isListening ? 0.3 : 1.0)
                            .animation(
                                speechRecognizer.isListening ?
                                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) :
                                .default,
                                value: speechRecognizer.isListening
                            )

                        Image(systemName: "mic.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 12) {
                        Text(speechRecognizer.isListening ? "Listening..." : "Ready to listen")
                            .font(.fdTitle3)
                            .foregroundColor(.fdText)

                        if speechRecognizer.isListening {
                            HStack(alignment: .center, spacing: 6) {
                                ForEach(0..<5, id: \.self) { index in
                                    WaveformBar(index: index)
                                }
                            }
                            .frame(height: 40)
                        }
                    }

                    if !speechRecognizer.transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recognized Text")
                                .font(.fdCaptionBold)
                                .foregroundColor(.fdTextSecondary)

                            Text(speechRecognizer.transcribedText)
                                .font(.fdBody)
                                .foregroundColor(.fdText)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.fdSurface)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        speechRecognizer.stopListening()
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.fdBodySemibold)
                            .foregroundColor(.fdText)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.fdSurfaceHover)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        Haptics.tock()
                        speechRecognizer.stopListening()
                        onSend(speechRecognizer.transcribedText)
                        dismiss()
                    }) {
                        Text("Send")
                            .font(.fdBodySemibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.fdAccent)
                            .cornerRadius(8)
                    }
                    .disabled(speechRecognizer.transcribedText.isEmpty)
                }
                .padding()
            }
        }
        .onAppear {
            speechRecognizer.startListening()
        }
    }
}

struct WaveformBar: View {
    let index: Int
    @State private var height: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.fdAccent)
            .frame(width: 4, height: height)
            .animation(
                Animation.easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1),
                value: height
            )
            .onAppear {
                height = CGFloat.random(in: 10...40)
            }
    }
}
