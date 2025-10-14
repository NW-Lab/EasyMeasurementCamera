//
//  LocalSettingsView.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/14.
//

import SwiftUI
import AVFoundation

struct LocalSettingsView: View {
    @ObservedObject var settings: CameraSettings
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // 露出設定
                Section("露出設定") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ISO: \(String(format: "%.0f", settings.isoValue))")
                            .font(.caption)
                        Slider(value: $settings.isoValue, in: 100...3200, step: 50)
                            .onChange(of: settings.isoValue) { _, _ in
                                cameraManager.applyCameraSettings()
                                settings.saveSettings()
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("シャッタースピード: 1/\(String(format: "%.0f", 1.0 / settings.exposureDuration))")
                            .font(.caption)
                        Slider(value: Binding(
                            get: { 1.0 / settings.exposureDuration },
                            set: { settings.exposureDuration = 1.0 / $0 }
                        ), in: 1...8000, step: 1)
                        .onChange(of: settings.exposureDuration) { _, _ in
                            cameraManager.applyCameraSettings()
                            settings.saveSettings()
                        }
                    }
                }
                
                // ホワイトバランス設定
                Section("ホワイトバランス") {
                    Picker("モード", selection: $settings.whiteBalanceMode) {
                        Text("オート").tag(AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance)
                        Text("ロック").tag(AVCaptureDevice.WhiteBalanceMode.locked)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.whiteBalanceMode) { _, _ in
                        cameraManager.applyCameraSettings()
                        settings.saveSettings()
                    }
                    
                    Button("晴天") {
                        applyWhiteBalancePreset(temperature: 5500)
                    }
                    
                    Button("曇天") {
                        applyWhiteBalancePreset(temperature: 6500)
                    }
                    
                    Button("蛍光灯") {
                        applyWhiteBalancePreset(temperature: 4000)
                    }
                    
                    Button("白熱灯") {
                        applyWhiteBalancePreset(temperature: 3200)
                    }
                }
            }
            .navigationTitle("ローカル設定")
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
    
    private func applyWhiteBalancePreset(temperature: Float) {
        settings.whiteBalanceMode = .locked
        // ホワイトバランスのプリセット適用
        // 実際の色温度変換は CameraManager で行う
        cameraManager.applyCameraSettings()
        settings.saveSettings()
    }
}
