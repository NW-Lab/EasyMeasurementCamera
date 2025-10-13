//
//  CameraSettingsView.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/13.
//

import SwiftUI
import AVFoundation

struct CameraSettingsView: View {
    @ObservedObject var settings: CameraSettings
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // 撮影モード設定
                captureModeSection
                
                // 露出設定
                exposureSection
                
                // フォーカス設定
                focusSection
                
                // ズーム・その他設定
                otherSettingsSection
                
                // リセット・保存
                actionSection
            }
            .navigationTitle("カメラ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("リセット") {
                        settings.resetToDefaults()
                        cameraManager.applyCameraSettings()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        cameraManager.applyCameraSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Capture Mode Section
    private var captureModeSection: some View {
        Section("撮影モード") {
            Picker("モード", selection: $settings.captureMode) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: settings.captureMode) { _, _ in
                settings.saveSettings()
            }
            
            if settings.captureMode == .video || settings.captureMode == .slowMotion {
                Picker("画質", selection: $settings.videoQuality) {
                    Text("標準").tag(AVCaptureSession.Preset.medium)
                    Text("高画質").tag(AVCaptureSession.Preset.high)
                    Text("4K").tag(AVCaptureSession.Preset.hd4K3840x2160)
                }
                .onChange(of: settings.videoQuality) { _, _ in
                    settings.saveSettings()
                }
            }
            
            if settings.captureMode == .slowMotion {
                Toggle("スローモーション有効", isOn: $settings.isSlowMotionEnabled)
                    .onChange(of: settings.isSlowMotionEnabled) { _, _ in
                        settings.saveSettings()
                    }
            }
        }
    }
    
    // MARK: - Exposure Section
    private var exposureSection: some View {
        Section("露出設定") {
            Picker("露出モード", selection: $settings.exposureMode) {
                Text("自動").tag(AVCaptureDevice.ExposureMode.autoExpose)
                Text("ロック").tag(AVCaptureDevice.ExposureMode.locked)
                Text("手動").tag(AVCaptureDevice.ExposureMode.custom)
            }
            .onChange(of: settings.exposureMode) {
                settings.saveSettings()
            }
            
            if settings.exposureMode == .custom {
                VStack(alignment: .leading) {
                    Text("ISO感度: \(Int(settings.isoValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $settings.isoValue, in: 29...2304, step: 1) {
                        Text("ISO")
                    }
                    .onChange(of: settings.isoValue) {
                        settings.saveSettings()
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("露出時間: 1/\(Int(1/settings.exposureDuration))秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { 1/settings.exposureDuration },
                        set: { settings.exposureDuration = 1/$0 }
                    ), in: 3...24000, step: 1) {
                        Text("シャッタースピード")
                    }
                    .onChange(of: settings.exposureDuration) {
                        settings.saveSettings()
                    }
                }
            }
        }
    }
    
    // MARK: - Focus Section
    private var focusSection: some View {
        Section("フォーカス設定") {
            Picker("フォーカスモード", selection: $settings.focusMode) {
                Text("自動").tag(AVCaptureDevice.FocusMode.autoFocus)
                Text("ロック").tag(AVCaptureDevice.FocusMode.locked)
                Text("連続自動").tag(AVCaptureDevice.FocusMode.continuousAutoFocus)
            }
            .onChange(of: settings.focusMode) {
                settings.saveSettings()
            }
            
            if settings.focusMode == .locked {
                VStack(alignment: .leading) {
                    Text("フォーカス位置: \(String(format: "%.2f", settings.lensPosition))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("近")
                            .font(.caption)
                        
                        Slider(value: $settings.lensPosition, in: 0...1, step: 0.01)
                            .onChange(of: settings.lensPosition) { _, _ in
                                settings.saveSettings()
                            }
                        
                        Text("遠")
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Other Settings Section
    private var otherSettingsSection: some View {
        Section("その他の設定") {
            VStack(alignment: .leading) {
                Text("ズーム倍率: \(String(format: "%.1f", settings.zoomFactor))×")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("1×")
                        .font(.caption)
                    
                    Slider(value: $settings.zoomFactor, in: 1.0...10.0, step: 0.1)
                        .onChange(of: settings.zoomFactor) { _, newValue in
                            cameraManager.zoom(by: newValue)
                        }
                    
                    Text("10×")
                        .font(.caption)
                }
            }
            
            Picker("ホワイトバランス", selection: $settings.whiteBalanceMode) {
                Text("自動").tag(AVCaptureDevice.WhiteBalanceMode.autoWhiteBalance)
                Text("ロック").tag(AVCaptureDevice.WhiteBalanceMode.locked)
            }
            .onChange(of: settings.whiteBalanceMode) {
                settings.saveSettings()
            }
            
            Picker("フラッシュ", selection: $settings.flashMode) {
                Text("オフ").tag(AVCaptureDevice.FlashMode.off)
                Text("自動").tag(AVCaptureDevice.FlashMode.auto)
                Text("オン").tag(AVCaptureDevice.FlashMode.on)
            }
            .onChange(of: settings.flashMode) {
                settings.saveSettings()
            }
        }
    }
    
    // MARK: - Action Section
    private var actionSection: some View {
        Section("アクション") {
            Button("設定を今すぐ適用") {
                cameraManager.applyCameraSettings()
            }
            .foregroundColor(.blue)
            
            Button("デフォルト設定に戻す") {
                settings.resetToDefaults()
                cameraManager.applyCameraSettings()
            }
            .foregroundColor(.red)
            
            HStack {
                Text("設定の保存")
                Spacer()
                Text("自動")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Settings Info View
struct CameraSettingsInfoView: View {
    let settings: CameraSettings
    
    var body: some View {
        List {
            Section("現在の設定値") {
                SettingsInfoRow(label: "撮影モード", value: settings.captureMode.displayName)
                SettingsInfoRow(label: "ISO感度", value: "\(Int(settings.isoValue))")
                SettingsInfoRow(label: "露出時間", value: "1/\(Int(1/settings.exposureDuration))秒")
                SettingsInfoRow(label: "フォーカス位置", value: String(format: "%.2f", settings.lensPosition))
                SettingsInfoRow(label: "ズーム倍率", value: String(format: "%.1fx", settings.zoomFactor))
                SettingsInfoRow(label: "フラッシュ", value: flashModeDescription)
            }
            
            Section("デバイス情報") {
                if let device = AVCaptureDevice.default(for: .video) {
                    SettingsInfoRow(label: "デバイス名", value: device.localizedName)
                    SettingsInfoRow(label: "最小ISO", value: "\(Int(device.activeFormat.minISO))")
                    SettingsInfoRow(label: "最大ISO", value: "\(Int(device.activeFormat.maxISO))")
                    SettingsInfoRow(label: "最大ズーム", value: String(format: "%.1fx", device.maxAvailableVideoZoomFactor))
                }
            }
        }
        .navigationTitle("設定情報")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var flashModeDescription: String {
        switch settings.flashMode {
        case .off: return "オフ"
        case .auto: return "自動"
        case .on: return "オン"
        @unknown default: return "不明"
        }
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CameraSettingsView(
        settings: CameraSettings(),
        cameraManager: CameraManager(settings: CameraSettings())
    )
}