//
//  MasterSettingsView.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/14.
//

import SwiftUI
import AVFoundation

struct MasterSettingsView: View {
    @ObservedObject var settings: CameraSettings
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // 撮影モード
                Section("撮影モード") {
                    Picker("モード", selection: $settings.captureMode) {
                        Text("写真").tag(CaptureMode.photo)
                        Text("ビデオ").tag(CaptureMode.video)
                        Text("スローモーション").tag(CaptureMode.slowMotion)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.captureMode) { _, _ in
                        settings.saveSettings()
                    }
                }
                
                // フォーカス設定
                Section("フォーカス設定") {
                    Picker("フォーカスモード", selection: $settings.focusMode) {
                        Text("オート").tag(AVCaptureDevice.FocusMode.autoFocus)
                        Text("連続オート").tag(AVCaptureDevice.FocusMode.continuousAutoFocus)
                        Text("マニュアル").tag(AVCaptureDevice.FocusMode.locked)
                    }
                    .onChange(of: settings.focusMode) { _, _ in
                        cameraManager.applyCameraSettings()
                        settings.saveSettings()
                    }
                    
                    // 無限遠フォーカスボタン
                    Button("無限遠にフォーカス") {
                        setInfinityFocus()
                    }
                    .foregroundColor(.blue)
                    
                    if settings.focusMode == .locked {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("レンズ位置: \(String(format: "%.2f", settings.lensPosition))")
                                .font(.caption)
                            Slider(value: $settings.lensPosition, in: 0...1)
                                .onChange(of: settings.lensPosition) { _, _ in
                                    cameraManager.applyCameraSettings()
                                    settings.saveSettings()
                                }
                        }
                    }
                }
                
                // フラッシュ設定
                Section("フラッシュ") {
                    Picker("フラッシュモード", selection: $settings.flashMode) {
                        Text("オフ").tag(AVCaptureDevice.FlashMode.off)
                        Text("オン").tag(AVCaptureDevice.FlashMode.on)
                        Text("オート").tag(AVCaptureDevice.FlashMode.auto)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.flashMode) { _, _ in
                        settings.saveSettings()
                    }
                }
            }
            .navigationTitle("マスター設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func setInfinityFocus() {
        settings.focusMode = .locked
        settings.lensPosition = 1.0
        cameraManager.applyCameraSettings()
        settings.saveSettings()
    }
}
