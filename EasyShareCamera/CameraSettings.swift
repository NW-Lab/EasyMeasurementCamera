//
//  CameraSettings.swift
//  EasyShareCamera
//
//  Created by システム on 2024/06/02.
//

import Foundation
import AVFoundation
import Combine

/// カメラ設定を管理するクラス
class CameraSettings: ObservableObject {
    // MARK: - Published Properties
    @Published var isoValue: Float = 100.0
    @Published var exposureDuration: Double = 1.0/60.0 // 1/60秒
    @Published var lensPosition: Float = 0.5 // 0.0 = 無限遠, 1.0 = 最近距離
    @Published var zoomFactor: CGFloat = 1.0
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var focusMode: AVCaptureDevice.FocusMode = .autoFocus
    @Published var exposureMode: AVCaptureDevice.ExposureMode = .autoExpose
    @Published var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .autoWhiteBalance
    
    // 撮影モード
    @Published var captureMode: CaptureMode = .photo
    @Published var videoQuality: AVCaptureSession.Preset = .high
    
    // MARK: - UserDefaults Keys
    private enum SettingsKey: String {
        case isoValue = "cameraSettings.isoValue"
        case exposureDuration = "cameraSettings.exposureDuration"
        case lensPosition = "cameraSettings.lensPosition"
        case zoomFactor = "cameraSettings.zoomFactor"
        case flashMode = "cameraSettings.flashMode"
        case focusMode = "cameraSettings.focusMode"
        case exposureMode = "cameraSettings.exposureMode"
        case whiteBalanceMode = "cameraSettings.whiteBalanceMode"
        case captureMode = "cameraSettings.captureMode"
        case videoQuality = "cameraSettings.videoQuality"
    }
    
    // MARK: - Initializer
    init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    /// 設定を UserDefaults から読み込み
    func loadSettings() {
        let defaults = UserDefaults.standard
        
        isoValue = defaults.object(forKey: SettingsKey.isoValue.rawValue) as? Float ?? 100.0
        exposureDuration = defaults.object(forKey: SettingsKey.exposureDuration.rawValue) as? Double ?? 1.0/60.0
        lensPosition = defaults.object(forKey: SettingsKey.lensPosition.rawValue) as? Float ?? 0.5
        zoomFactor = defaults.object(forKey: SettingsKey.zoomFactor.rawValue) as? CGFloat ?? 1.0
        
        // Enum値の読み込み
        if let flashModeRaw = defaults.object(forKey: SettingsKey.flashMode.rawValue) as? Int {
            flashMode = AVCaptureDevice.FlashMode(rawValue: flashModeRaw) ?? .off
        }
        if let focusModeRaw = defaults.object(forKey: SettingsKey.focusMode.rawValue) as? Int {
            focusMode = AVCaptureDevice.FocusMode(rawValue: focusModeRaw) ?? .autoFocus
        }
        if let exposureModeRaw = defaults.object(forKey: SettingsKey.exposureMode.rawValue) as? Int {
            exposureMode = AVCaptureDevice.ExposureMode(rawValue: exposureModeRaw) ?? .autoExpose
        }
        if let whiteBalanceModeRaw = defaults.object(forKey: SettingsKey.whiteBalanceMode.rawValue) as? Int {
            whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode(rawValue: whiteBalanceModeRaw) ?? .autoWhiteBalance
        }
        if let captureModeRaw = defaults.object(forKey: SettingsKey.captureMode.rawValue) as? String {
            captureMode = CaptureMode(rawValue: captureModeRaw) ?? .photo
        }
        if let videoQualityRaw = defaults.object(forKey: SettingsKey.videoQuality.rawValue) as? String {
            // AVCaptureSession.Preset(rawValue:) returns a Preset (non-optional), so assign directly.
            videoQuality = AVCaptureSession.Preset(rawValue: videoQualityRaw)
        }
    }
    
    /// 設定を UserDefaults に保存
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(isoValue, forKey: SettingsKey.isoValue.rawValue)
        defaults.set(exposureDuration, forKey: SettingsKey.exposureDuration.rawValue)
        defaults.set(lensPosition, forKey: SettingsKey.lensPosition.rawValue)
        defaults.set(zoomFactor, forKey: SettingsKey.zoomFactor.rawValue)
        defaults.set(flashMode.rawValue, forKey: SettingsKey.flashMode.rawValue)
        defaults.set(focusMode.rawValue, forKey: SettingsKey.focusMode.rawValue)
        defaults.set(exposureMode.rawValue, forKey: SettingsKey.exposureMode.rawValue)
        defaults.set(whiteBalanceMode.rawValue, forKey: SettingsKey.whiteBalanceMode.rawValue)
        defaults.set(captureMode.rawValue, forKey: SettingsKey.captureMode.rawValue)
        defaults.set(videoQuality.rawValue, forKey: SettingsKey.videoQuality.rawValue)
    }
    
    /// 設定をデフォルト値にリセット
    func resetToDefaults() {
        isoValue = 100.0
        exposureDuration = 1.0/60.0
        lensPosition = 0.5
        zoomFactor = 1.0
        flashMode = .off
        focusMode = .autoFocus
        exposureMode = .autoExpose
        whiteBalanceMode = .autoWhiteBalance
        captureMode = .photo
        videoQuality = .high
        
        saveSettings()
    }
    
    /// 現在の設定をデバイスの制限内で調整
    func validateAndAdjustSettings(for device: AVCaptureDevice) {
        // ISO値の調整
        let minISO = device.activeFormat.minISO
        let maxISO = device.activeFormat.maxISO
        isoValue = max(minISO, min(maxISO, isoValue))
        
        // 露出時間の調整
        let minDuration = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxDuration = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        exposureDuration = max(minDuration, min(maxDuration, exposureDuration))
        
        // ズーム倍率の調整
        zoomFactor = max(device.minAvailableVideoZoomFactor, min(device.maxAvailableVideoZoomFactor, zoomFactor))
        
        saveSettings()
    }
    
    /// 設定が変更されたときに自動保存するためのメソッド
    func settingDidChange() {
        saveSettings()
    }
}

// MARK: - Supporting Types

enum CaptureMode: String, CaseIterable {
    case photo = "photo"
    case video = "video"
    case slowMotion = "slowMotion"
    
    var displayName: String {
        switch self {
        case .photo:
            return "写真"
        case .video:
            return "動画"
        case .slowMotion:
            return "スローモーション"
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// カメラ設定をすべてクリア（デバッグ用）
    func clearCameraSettings() {
        let keys = [
            "cameraSettings.isoValue",
            "cameraSettings.exposureDuration",
            "cameraSettings.lensPosition",
            "cameraSettings.zoomFactor",
            "cameraSettings.flashMode",
            "cameraSettings.focusMode",
            "cameraSettings.exposureMode",
            "cameraSettings.whiteBalanceMode",
            "cameraSettings.captureMode",
            "cameraSettings.videoQuality"
        ]
        
        keys.forEach { removeObject(forKey: $0) }
    }
}