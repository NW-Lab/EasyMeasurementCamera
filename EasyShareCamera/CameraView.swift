//
//  CameraView.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/13.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraSettings: CameraSettings
    @StateObject private var cameraManager: CameraManager
    @State private var showingMasterSettings = false
    @State private var showingLocalSettings = false
    @State private var showingAlert = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var lastZoomFactor: CGFloat = 1.0
    @State private var availableZoomFactors: [CGFloat] = []
    
    init() {
        let settings = CameraSettings()
        _cameraSettings = StateObject(wrappedValue: settings)
        _cameraManager = StateObject(wrappedValue: CameraManager(settings: settings))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.hasPermission {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                guard let device = cameraManager.captureDevice else { return }
                                // 段階的拡大: 1→2→4→8倍のような感じに
                                let sensitivity: CGFloat = 0.2  // より感度を下げる
                                let logScale = log2(value) * sensitivity  // 対数スケールで段階的に
                                let newZoom = lastZoomFactor * pow(2.0, logScale)
                                let maxPracticalZoom = min(device.maxAvailableVideoZoomFactor, 10.0)
                                let clampedZoom = min(max(newZoom, device.minAvailableVideoZoomFactor), maxPracticalZoom)
                                cameraManager.zoom(by: clampedZoom)
                            }
                            .onEnded { _ in
                                lastZoomFactor = cameraSettings.zoomFactor
                            }
                    )
                    .onTapGesture { location in
                        let point = CGPoint(x: location.x / UIScreen.main.bounds.width,
                                          y: location.y / UIScreen.main.bounds.height)
                        cameraManager.setFocusPoint(point)
                    }
                
                VStack {
                    // 上部コントロール
                    topControls
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    // 下部コントロール
                    bottomControls
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                }
            } else {
                permissionView
            }
        }
        .onAppear {
            print("📱 [CameraView] onAppear - hasPermission: \(cameraManager.hasPermission)")
            lastZoomFactor = cameraSettings.zoomFactor
            
            if cameraManager.hasPermission {
                cameraManager.startSession()
                // セッション開始後にズーム倍率を取得
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if availableZoomFactors.isEmpty {
                        availableZoomFactors = cameraManager.getAvailableZoomFactors()
                    }
                }
            } else {
                print("📱 [CameraView] No camera permission yet")
            }
        }
        .onDisappear {
            print("📱 [CameraView] onDisappear")
            cameraManager.stopSession()
        }
        .alert("エラー", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(cameraManager.alertError?.message ?? "")
        }
        .onChange(of: cameraManager.alertError) { _, _ in
            showingAlert = cameraManager.alertError != nil
        }
        .onChange(of: cameraManager.hasPermission) { _, newValue in
            print("📱 [CameraView] Permission changed to: \(newValue)")
            if newValue {
                cameraManager.startSession()
                // 権限許可後にズーム倍率を取得
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if availableZoomFactors.isEmpty {
                        availableZoomFactors = cameraManager.getAvailableZoomFactors()
                    }
                }
            } else {
                cameraManager.stopSession()
            }
        }
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            if isRecording {
                startRecordingTimer()
            } else {
                stopRecordingTimer()
            }
        }
        .onChange(of: cameraSettings.zoomFactor) { _, newValue in
            lastZoomFactor = newValue
        }
        .sheet(isPresented: $showingMasterSettings) {
            MasterSettingsView(settings: cameraSettings, cameraManager: cameraManager)
        }
        .sheet(isPresented: $showingLocalSettings) {
            LocalSettingsView(settings: cameraSettings, cameraManager: cameraManager)
        }
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        HStack {
            // マスター設定ボタン
            Button(action: { showingMasterSettings = true }) {
                VStack(spacing: 2) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                    Text("Master")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
            
            // 中央エリア: マスター表示とモード表示
            VStack(spacing: 4) {
                Text("MASTER")
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .bold()
                
                HStack(spacing: 8) {
                    Text(cameraSettings.captureMode.displayName)
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    // 録画時間表示（録画中のみ）
                    if cameraManager.isRecording {
                        Text(formatDuration(recordingDuration))
                            .foregroundColor(.red)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // ローカル設定ボタン
            Button(action: { showingLocalSettings = true }) {
                VStack(spacing: 2) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                    Text("Local")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // ズーム倍率表示とボタン
            VStack(spacing: 12) {
                // 現在のズーム倍率表示
                Text(String(format: "%.1fx", cameraSettings.zoomFactor))
                    .foregroundColor(.white)
                    .font(.title3)
                    .bold()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                
                // キリの良い倍率ボタン
                HStack(spacing: 12) {
                    ForEach(availableZoomFactors, id: \.self) { factor in
                        Button(action: {
                            cameraManager.zoom(by: factor)
                        }) {
                            Text(formatZoomFactor(factor))
                                .foregroundColor(.white)
                                .font(.callout)
                                .bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white, lineWidth: abs(cameraSettings.zoomFactor - factor) < 0.1 ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // シャッターボタン
            HStack(spacing: 0) {
                // 左側のスペーサー
                Spacer()
                
                // メインシャッターボタン（中央）
                Button(action: mainCaptureAction) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                        
                        if cameraManager.isRecording {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Circle()
                                .fill(captureButtonColor)
                                .frame(width: 70, height: 70)
                        }
                    }
                }
                .scaleEffect(cameraManager.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: cameraManager.isRecording)
                
                // 右側のスペーサー
                Spacer()
            }
        }
    }
    
    // MARK: - Permission View
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("カメラへのアクセスが必要です")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("設定からカメラの使用を許可してください")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("設定を開く") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .foregroundColor(.blue)
            .font(.headline)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    private var captureButtonColor: Color {
        switch cameraSettings.captureMode {
        case .photo:
            return .clear
        case .video, .slowMotion:
            return .red
        }
    }
    
    // MARK: - Actions
    private func mainCaptureAction() {
        switch cameraSettings.captureMode {
        case .photo:
            cameraManager.capturePhoto()
        case .video, .slowMotion:
            cameraManager.toggleRecording()
        }
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let deciseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, deciseconds)
    }
    
    private func formatZoomFactor(_ factor: CGFloat) -> String {
        if factor == floor(factor) {
            return String(format: "%.0fx", factor)
        } else {
            return String(format: "%.1fx", factor)
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = .black

#if targetEnvironment(simulator)
        // Simulator: カメラプレビューは利用できないためプレースホルダを表示
        print("📱 [CameraPreviewView] Running on SIMULATOR - showing placeholder")
        let placeholder = UIImageView(image: UIImage(systemName: "camera.fill"))
        placeholder.contentMode = .center
        placeholder.tintColor = .gray
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholder.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            placeholder.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
        return view
#else
        // Real device: カメラプレビューレイヤーを作成
        print("📱 [CameraPreviewView] Running on REAL DEVICE - setting up preview layer")
        print("📱 [CameraPreviewView] Session is running: \(session.isRunning)")
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        print("📱 [CameraPreviewView] ✅ Preview layer added to view")
        return view
#endif
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
                print("📱 [CameraPreviewView] updateUIView - frame updated to: \(uiView.bounds)")
            }
            // iOS 17 での deprecated API を避けるため、ここではプレビューの向き設定は行わない。
            // デバイス上では AVFoundation が適切にプレビューの向きを処理することを期待する。
            previewLayer.needsDisplayOnBoundsChange = true
        }
    }
}

#Preview {
    CameraView()
}