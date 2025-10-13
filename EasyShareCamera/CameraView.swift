//
//  CameraView.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/13.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraSettings = CameraSettings()
    @StateObject private var cameraManager: CameraManager
    @State private var showingSettings = false
    @State private var showingAlert = false
    
    init() {
        let settings = CameraSettings()
        let manager = CameraManager(settings: settings)
        _cameraManager = StateObject(wrappedValue: manager)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.hasPermission {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()
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
            if cameraManager.hasPermission {
                cameraManager.startSession()
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
            } else {
                cameraManager.stopSession()
            }
        }
        .sheet(isPresented: $showingSettings) {
            CameraSettingsView(settings: cameraSettings, cameraManager: cameraManager)
        }
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        HStack {
            // 設定ボタン
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // 撮影モード表示
            Text(cameraSettings.captureMode.displayName)
                .foregroundColor(.white)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
            
            Spacer()
            
            // フラッシュボタン
            Button(action: toggleFlash) {
                Image(systemName: flashIconName)
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // ズームスライダー
            if cameraSettings.zoomFactor > 1.0 {
                HStack {
                    Text("1×")
                        .foregroundColor(.white)
                        .font(.caption)
                    
                    Slider(value: Binding(
                        get: { cameraSettings.zoomFactor },
                        set: { newValue in
                            cameraSettings.zoomFactor = newValue
                            cameraManager.zoom(by: newValue)
                        }
                    ), in: 1.0...10.0, step: 0.1)
                    .accentColor(.yellow)
                    
                    Text("10×")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.horizontal, 40)
            }
            
            HStack(spacing: 60) {
                // 撮影モード切り替え
                Button(action: switchCaptureMode) {
                    Image(systemName: captureModeIcon)
                        .foregroundColor(.white)
                        .font(.title)
                        .padding(20)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                // メインシャッターボタン
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
                
                // 設定クイックアクセス
                Button(action: { showingSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.white)
                        .font(.title)
                        .padding(20)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
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
    private var flashIconName: String {
        switch cameraSettings.flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.a.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }
    
    private var captureModeIcon: String {
        switch cameraSettings.captureMode {
        case .photo:
            return "camera.fill"
        case .video:
            return "video.fill"
        case .slowMotion:
            return "slowmo"
        }
    }
    
    private var captureButtonColor: Color {
        switch cameraSettings.captureMode {
        case .photo:
            return .clear
        case .video, .slowMotion:
            return .red
        }
    }
    
    // MARK: - Actions
    private func toggleFlash() {
        switch cameraSettings.flashMode {
        case .off:
            cameraSettings.flashMode = .auto
        case .auto:
            cameraSettings.flashMode = .on
        case .on:
            cameraSettings.flashMode = .off
        @unknown default:
            cameraSettings.flashMode = .off
        }
        cameraSettings.saveSettings()
    }
    
    private func switchCaptureMode() {
        switch cameraSettings.captureMode {
        case .photo:
            cameraSettings.captureMode = .video
        case .video:
            cameraSettings.captureMode = .slowMotion
        case .slowMotion:
            cameraSettings.captureMode = .photo
        }
        cameraSettings.saveSettings()
    }
    
    private func mainCaptureAction() {
        switch cameraSettings.captureMode {
        case .photo:
            cameraManager.capturePhoto()
        case .video, .slowMotion:
            cameraManager.toggleRecording()
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