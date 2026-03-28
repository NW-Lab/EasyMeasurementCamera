//
//  RecordingPreviewView.swift
//  EasyShareCamera
//
//  録画プレビュー表示
//

import SwiftUI
import AVKit
import Combine
import AVFoundation

struct RecordingPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let videoURL: URL
    @State private var player = AVPlayer()
    @State private var isReadyToPlay = false
    @State private var loadError: String?
    @State private var errorLogMessage: String?
    @State private var assetInfoMessage: String?
    @State private var fileInfoMessage: String?
    @State private var isPlaybackEnded = false
    @State private var remainingLoops = 1
    @State private var statusCancellable: AnyCancellable?
    @State private var failureCancellable: AnyCancellable?
    @State private var endCancellable: AnyCancellable?
    @State private var prepareTask: Task<Void, Never>?
    @AppStorage(SettingsKeys.showPreviewDiagnostics) private var showPreviewDiagnostics = SettingsDefaults.defaultShowPreviewDiagnostics
    @AppStorage(SettingsKeys.autoClosePreview) private var autoClosePreview = SettingsDefaults.defaultAutoClosePreview
    @AppStorage(SettingsKeys.previewPlaybackRate) private var previewPlaybackRate = SettingsDefaults.defaultPreviewPlaybackRate
    @AppStorage(SettingsKeys.previewLoopCount) private var previewLoopCount = SettingsDefaults.defaultPreviewLoopCount

    var body: some View {
        NavigationView {
            ZStack {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)

                if let loadError {
                    VStack(spacing: 8) {
                        Text("プレビューを再生できません")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(loadError)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        if showPreviewDiagnostics, let errorLogMessage {
                            Text(errorLogMessage)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        if showPreviewDiagnostics, let assetInfoMessage {
                            Text(assetInfoMessage)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        if showPreviewDiagnostics, let fileInfoMessage {
                            Text(fileInfoMessage)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                } else if !isReadyToPlay {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        if showPreviewDiagnostics, let assetInfoMessage {
                            Text(assetInfoMessage)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        if showPreviewDiagnostics, let fileInfoMessage {
                            Text(fileInfoMessage)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                if !autoClosePreview, isPlaybackEnded, loadError == nil {
                    Button(action: replay) {
                        HStack(spacing: 8) {
                            Image(systemName: "goforward")
                            Text("もう一度再生")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                }
            }
            .background(Color.black)
            .onAppear {
                activateAudioSession()
                updateFileInfo()
                preparePlayback()
            }
            .onDisappear {
                prepareTask?.cancel()
                player.pause()
                statusCancellable?.cancel()
                failureCancellable?.cancel()
                endCancellable?.cancel()
            }
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func configurePlayer(with item: AVPlayerItem) {
        isReadyToPlay = false
        isPlaybackEnded = false
        remainingLoops = max(1, previewLoopCount)
        loadError = nil
        errorLogMessage = nil

        player.replaceCurrentItem(with: item)

        endCancellable = NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                if autoClosePreview {
                    handleAutoCloseLoop()
                } else {
                    isPlaybackEnded = true
                }
            }

        failureCancellable = NotificationCenter.default
            .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                let error = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError)
                self.loadError = error?.localizedDescription ?? "再生に失敗しました"
                self.errorLogMessage = self.buildErrorLogMessage(from: item)
            }

        statusCancellable = item.publisher(for: \.status, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .readyToPlay:
                    self.isReadyToPlay = true
                    self.player.play()
                    self.applyPlaybackRate()
                case .failed:
                    self.loadError = item.error?.localizedDescription ?? "不明なエラー"
                    self.errorLogMessage = self.buildErrorLogMessage(from: item)
                default:
                    break
                }
            }
    }

    private func applyPlaybackRate() {
        let rate = Float(previewPlaybackRate)
        if rate > 0 {
            player.rate = rate
        }
    }

    private func startPlaybackFromBeginning() {
        player.seek(to: .zero) { _ in
            player.play()
            applyPlaybackRate()
        }
    }

    private func handleAutoCloseLoop() {
        if remainingLoops > 1 {
            remainingLoops -= 1
            startPlaybackFromBeginning()
        } else {
            dismiss()
        }
    }

    private func preparePlayback() {
        prepareTask?.cancel()
        prepareTask = Task { [videoURL] in
            let asset = AVURLAsset(url: videoURL)
            do {
                let isPlayable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration)
                let tracks = try await asset.load(.tracks)
                let durationSeconds = duration.seconds.isFinite ? duration.seconds : 0
                await MainActor.run {
                    self.assetInfoMessage = "playable=\(isPlayable) duration=\(String(format: "%.2f", durationSeconds))s tracks=\(tracks.count)"
                }

                guard isPlayable, durationSeconds > 0 else {
                    await MainActor.run {
                        self.loadError = "再生準備が完了していません"
                    }
                    return
                }

                let item = AVPlayerItem(asset: asset)
                await MainActor.run {
                    self.configurePlayer(with: item)
                }
            } catch {
                await MainActor.run {
                    self.loadError = error.localizedDescription
                }
            }
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("⚠️ [RecordingPreviewView] Failed to activate audio session: \(error)")
        }
    }

    private func buildErrorLogMessage(from item: AVPlayerItem) -> String? {
        guard let events = item.errorLog()?.events, !events.isEmpty else { return nil }
        let messages = events.prefix(3).map { event in
            let status = event.errorStatusCode
            let domain = event.errorDomain
            let comment = event.errorComment ?? ""
            return "\(domain) (\(status)) \(comment)"
        }
        return messages.joined(separator: "\n")
    }

    private func updateFileInfo() {
        let path = videoURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            fileInfoMessage = "file=missing"
            return
        }

        let attrs = (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let date = (attrs[.modificationDate] as? Date)?.description ?? "n/a"
        fileInfoMessage = "file=exists size=\(size) modified=\(date)"
    }

    private func replay() {
        isPlaybackEnded = false
        startPlaybackFromBeginning()
    }
}

#Preview {
    RecordingPreviewView(videoURL: URL(fileURLWithPath: "/dev/null"))
}
