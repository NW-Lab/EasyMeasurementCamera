//
//  CaptureSettings.swift
//  EasyShareCamera
//
//  設定キーと撮影モード定義
//

import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case single
    case continuous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single:
            return "1ショット"
        case .continuous:
            return "連続撮影"
        }
    }
}

enum SettingsKeys {
    static let captureMode = "captureMode"
    static let showTestCaptureButton = "showTestCaptureButton"
    static let showRecordingPreview = "showRecordingPreview"
    static let saveToPhotoLibrary = "saveToPhotoLibrary"
    static let showPreviewDiagnostics = "showPreviewDiagnostics"
    static let autoClosePreview = "autoClosePreview"
    static let previewPlaybackRate = "previewPlaybackRate"
    static let previewLoopCount = "previewLoopCount"
    static let dropHeightCm = "dropHeightCm"
    static let recordingDurationSeconds = "recordingDurationSeconds"
    static let zoomFactor = "zoomFactor"
    static let focusLocked = "focusLocked"
}

enum SettingsDefaults {
    #if DEBUG
    static let defaultShowTestCaptureButton = true
    static let defaultShowPreviewDiagnostics = true
    #else
    static let defaultShowTestCaptureButton = false
    static let defaultShowPreviewDiagnostics = false
    #endif
    static let defaultAutoClosePreview = false
    static let defaultPreviewPlaybackRate = 0.5
    static let defaultPreviewLoopCount = 1
    static let defaultDropHeightCm = 30.0
    static let defaultRecordingDurationSeconds = 4.0
    static let defaultZoomFactor = 1.0
    static let defaultFocusLocked = false

    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKeys.captureMode: CaptureMode.single.rawValue,
            SettingsKeys.showRecordingPreview: false,
            SettingsKeys.showTestCaptureButton: defaultShowTestCaptureButton,
            SettingsKeys.saveToPhotoLibrary: true,
            SettingsKeys.showPreviewDiagnostics: defaultShowPreviewDiagnostics,
            SettingsKeys.autoClosePreview: defaultAutoClosePreview,
            SettingsKeys.previewPlaybackRate: defaultPreviewPlaybackRate,
            SettingsKeys.previewLoopCount: defaultPreviewLoopCount,
            SettingsKeys.dropHeightCm: defaultDropHeightCm,
            SettingsKeys.recordingDurationSeconds: defaultRecordingDurationSeconds,
            SettingsKeys.zoomFactor: defaultZoomFactor,
            SettingsKeys.focusLocked: defaultFocusLocked
        ])
    }
}
