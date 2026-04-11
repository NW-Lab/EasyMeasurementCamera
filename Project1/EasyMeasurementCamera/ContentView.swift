//
//  ContentView.swift
//  EasyShareCamera
//
//  ミルククラウン撮影用のメインUI
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showInfo = false
    @State private var previewURL: URL?
    @State private var isShowingPreview = false
    @State private var showSettings = false
    @State private var zoomStartFactor: Double?
    @State private var focusMode: FocusMode = .auto
    @State private var focusPosition: Float = 0.5

    @AppStorage(SettingsKeys.captureMode) private var captureModeRaw = CaptureMode.single.rawValue
    @AppStorage(SettingsKeys.showRecordingPreview) private var showRecordingPreview = false
    @AppStorage(SettingsKeys.showTestCaptureButton) private var showTestCaptureButton = SettingsDefaults.defaultShowTestCaptureButton
    @AppStorage(SettingsKeys.saveToPhotoLibrary) private var saveToPhotoLibrary = true
    @AppStorage(SettingsKeys.dropHeightCm) private var dropHeightCm = SettingsDefaults.defaultDropHeightCm
    @AppStorage(SettingsKeys.recordingDurationSeconds) private var recordingDurationSeconds = SettingsDefaults.defaultRecordingDurationSeconds
    @AppStorage(SettingsKeys.zoomFactor) private var zoomFactor = SettingsDefaults.defaultZoomFactor
    @AppStorage(SettingsKeys.focusLocked) private var focusLocked = SettingsDefaults.defaultFocusLocked

    private var captureMode: CaptureMode {
        get { CaptureMode(rawValue: captureModeRaw) ?? .single }
        set { captureModeRaw = newValue.rawValue }
    }

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
                .gesture(magnificationGesture)

            VStack {
                topInfoButton
                Spacer()
                statusView
                Spacer()
                controlButtons
                focusControls
            }
        }
        .onAppear {
            SettingsDefaults.register()
            reloadSettingsFromDefaults()
            cameraManager.startSession()
            syncSettings()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadSettingsFromDefaults()
            syncSettings()
        }
        .onChange(of: captureModeRaw) { _, _ in
            syncSettings()
        }
        .onChange(of: showRecordingPreview) { _, _ in
            syncSettings()
        }
        .onChange(of: saveToPhotoLibrary) { _, _ in
            syncSettings()
        }
        .onChange(of: dropHeightCm) { _, _ in
            syncSettings()
        }
        .onChange(of: recordingDurationSeconds) { _, _ in
            syncSettings()
        }
        .onChange(of: zoomFactor) { _, _ in
            syncSettings()
        }
        .onChange(of: focusLocked) { _, _ in
            syncSettings()
        }
        .onChange(of: focusMode) { _, _ in
            syncSettings()
        }
        .onChange(of: focusPosition) { _, _ in
            syncSettings()
        }
        .onChange(of: isShowingPreview) { _, showing in
            if showing {
                cameraManager.stopSession()
            } else {
                cameraManager.startSession()
            }
        }
        .onChange(of: cameraManager.lastRecordedURL) { _, newValue in
            guard showRecordingPreview, let url = newValue else { return }
            previewURL = url
            isShowingPreview = true
        }
        .sheet(isPresented: $showInfo) {
            InfoView(onOpenSettings: {
                showInfo = false
                DispatchQueue.main.async {
                    showSettings = true
                }
            })
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isShowingPreview, onDismiss: {
            cameraManager.clearLastRecording()
            previewURL = nil
        }) {
            if let previewURL {
                RecordingPreviewView(videoURL: previewURL)
            }
        }
        .alert(item: $cameraManager.alertError) { error in
            Alert(
                title: Text("エラー"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var topInfoButton: some View {
        HStack {
            Spacer()
            Button(action: { showInfo.toggle() }) {
                Image(systemName: "info.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing)
        }
        .padding(.top, 50)
    }

    private var statusView: some View {
        Group {
            if cameraManager.isRecording {
                VStack(spacing: 16) {
                    Text("録画中...")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    ProgressView(value: cameraManager.recordingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .frame(width: 200)

                    Text("\(Int(cameraManager.recordingProgress * 100))%")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            } else if cameraManager.isArmed {
                VStack(spacing: 8) {
                    Text("撮影待機")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text(showTestCaptureButton ? "赤色LEDの点灯、または試し撮影を押してください" : "赤色LEDの点灯を待っています")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
        }
    }

    private var controlButtons: some View {
        VStack(spacing: 20) {
            if cameraManager.isArmed {
                if showTestCaptureButton {
                    Button(action: { cameraManager.startTestRecording() }) {
                        HStack {
                            Image(systemName: "video.circle")
                            Text("試し撮影")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(8)
                    }
                    .disabled(cameraManager.isRecording)
                }

                Button(action: { cameraManager.disarmCapture() }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("キャンセル")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
                .disabled(cameraManager.isRecording)
            } else {
                Button(action: { cameraManager.armCapture() }) {
                    HStack {
                        Image(systemName: "target")
                        Text("撮影準備")
                            .fontWeight(.bold)
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(cameraManager.isRecording)
            }
        }
        .padding(.bottom, 50)
    }

    private var focusControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ズーム: \(String(format: "%.1f", zoomFactor))x")
                    .foregroundColor(.white)
                Slider(value: $zoomFactor, in: 1.0...cameraManager.maxZoomFactor(), step: 0.1)
            }
            .padding(12)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)

            Picker("フォーカス", selection: $focusMode) {
                Text("自動").tag(FocusMode.auto)
                Text("手動").tag(FocusMode.manual)
            }
            .pickerStyle(.segmented)

            if focusMode == .manual {
                HStack {
                    Text("手動フォーカス")
                        .foregroundColor(.white)
                    Slider(value: Binding(
                        get: { Double(focusPosition) },
                        set: { focusPosition = Float($0) }
                    ), in: 0.0...1.0)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .padding(.bottom, 16)
    }

    private func syncSettings() {
        cameraManager.updateCaptureMode(isContinuous: captureMode == .continuous)
        cameraManager.updatePreviewEnabled(showRecordingPreview)
        cameraManager.updateSaveToPhotoLibraryEnabled(saveToPhotoLibrary)
        cameraManager.updateDropHeightCentimeters(dropHeightCm)
        cameraManager.updateRecordingDurationSeconds(recordingDurationSeconds)
        cameraManager.updateZoomFactor(zoomFactor)
        cameraManager.updateFocusLocked(focusLocked)
        cameraManager.updateFocusMode(isManual: focusMode == .manual)
        cameraManager.updateFocusPosition(focusPosition)
    }

    private func reloadSettingsFromDefaults() {
        let defaults = UserDefaults.standard
        if let mode = defaults.string(forKey: SettingsKeys.captureMode) {
            captureModeRaw = mode
        }
        showRecordingPreview = defaults.bool(forKey: SettingsKeys.showRecordingPreview)
        showTestCaptureButton = defaults.bool(forKey: SettingsKeys.showTestCaptureButton)
        saveToPhotoLibrary = defaults.bool(forKey: SettingsKeys.saveToPhotoLibrary)
        dropHeightCm = defaults.double(forKey: SettingsKeys.dropHeightCm)
        recordingDurationSeconds = defaults.double(forKey: SettingsKeys.recordingDurationSeconds)
        zoomFactor = defaults.double(forKey: SettingsKeys.zoomFactor)
        focusLocked = defaults.bool(forKey: SettingsKeys.focusLocked)
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = cameraManager.getPreviewLayer()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Info View

struct InfoView: View {
    @Environment(\.dismiss) var dismiss
    let onOpenSettings: (() -> Void)?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // アプリ説明
                    Section {
                        Text("EasyShareCamera")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("ミルククラウン撮影システム")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)

                    Section {
                        Button("設定を開く") {
                            dismiss()
                            onOpenSettings?()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom)

                    // 使い方
                    Section {
                        Text("使い方")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(number: "1", text: "カメラを三脚に固定し、ミルククラウンが発生する位置を画面中央に合わせます")
                            InfoRow(number: "2", text: "赤色LEDを撮影領域に配置します（水滴検知センサーと連動）")
                            InfoRow(number: "3", text: "「撮影準備」ボタンをタップします")
                            InfoRow(number: "4", text: "水滴を落とすと、赤色LEDが点灯し、自動的に録画が開始されます")
                            InfoRow(number: "5", text: "録画は4秒間自動で行われ、写真ライブラリに保存されます")
                        }
                    }
                    .padding(.bottom)

                    // 技術仕様
                    Section {
                        Text("技術仕様")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            SpecRow(label: "落下高さ", value: "30cm")
                            SpecRow(label: "落下時間", value: "約247ms")
                            SpecRow(label: "フレームレート", value: "240fps")
                            SpecRow(label: "録画時間", value: "4秒")
                            SpecRow(label: "総フレーム数", value: "960フレーム")
                            SpecRow(label: "検知方式", value: "赤色LED光学検知")
                        }
                    }
                    .padding(.bottom)

                    // 注意事項
                    Section {
                        Text("注意事項")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 撮影環境は暗めにし、赤色LEDを明確に検知できるようにしてください")
                            Text("• 赤色LED以外の強い光源（赤い照明など）は避けてください")
                            Text("• カメラは必ず固定してください（手持ち撮影は非推奨）")
                            Text("• 初回撮影前に写真ライブラリへのアクセスを許可してください")
                        }
                        .font(.callout)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
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
}

// MARK: - Helper Views

struct InfoRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SpecRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

private enum FocusMode {
    case auto
    case manual
}

private extension ContentView {
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomStartFactor == nil {
                    zoomStartFactor = zoomFactor
                }
                let base = zoomStartFactor ?? zoomFactor
                let maxZoom = cameraManager.maxZoomFactor()
                let newZoom = min(max(1.0, base * value), maxZoom)
                zoomFactor = newZoom
            }
            .onEnded { _ in
                zoomStartFactor = nil
            }
    }
}
