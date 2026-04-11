//
//  SettingsView.swift
//  EasyShareCamera
//
//  アプリ内設定画面
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.captureMode) private var captureModeRaw = CaptureMode.single.rawValue
    @AppStorage(SettingsKeys.showRecordingPreview) private var showRecordingPreview = false
    @AppStorage(SettingsKeys.showTestCaptureButton) private var showTestCaptureButton = false
    @AppStorage(SettingsKeys.showPreviewDiagnostics) private var showPreviewDiagnostics = SettingsDefaults.defaultShowPreviewDiagnostics
    @AppStorage(SettingsKeys.autoClosePreview) private var autoClosePreview = SettingsDefaults.defaultAutoClosePreview
    @AppStorage(SettingsKeys.previewPlaybackRate) private var previewPlaybackRate = SettingsDefaults.defaultPreviewPlaybackRate
    @AppStorage(SettingsKeys.previewLoopCount) private var previewLoopCount = SettingsDefaults.defaultPreviewLoopCount
    @AppStorage(SettingsKeys.dropHeightCm) private var dropHeightCm = SettingsDefaults.defaultDropHeightCm
    @AppStorage(SettingsKeys.recordingDurationSeconds) private var recordingDurationSeconds = SettingsDefaults.defaultRecordingDurationSeconds
    @AppStorage(SettingsKeys.zoomFactor) private var zoomFactor = SettingsDefaults.defaultZoomFactor
    @AppStorage(SettingsKeys.focusLocked) private var focusLocked = SettingsDefaults.defaultFocusLocked

    private let dropHeightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.minimum = 15
        formatter.maximum = 50
        return formatter
    }()

    private let zoomFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        formatter.minimum = 1
        formatter.maximum = 5
        return formatter
    }()

    var body: some View {
        NavigationView {
            Form {
                Section("撮影モード") {
                    Picker("撮影モード", selection: $captureModeRaw) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("撮影条件") {
                    HStack {
                        Text("落下距離")
                        Spacer()
                        TextField("30", value: $dropHeightCm, formatter: dropHeightFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundColor(.secondary)
                    }
                    Stepper(value: $dropHeightCm, in: 15...50, step: 0.5) {
                        Text("\(dropHeightCm, specifier: "%.1f")cm")
                            .foregroundColor(.secondary)
                    }
                    Picker("撮影時間", selection: $recordingDurationSeconds) {
                        Text("1秒").tag(1.0)
                        Text("2秒").tag(2.0)
                        Text("3秒").tag(3.0)
                        Text("4秒").tag(4.0)
                    }
                    .pickerStyle(.segmented)
                }

                Section("カメラ") {
                    HStack {
                        Text("光学倍率")
                        Spacer()
                        TextField("1.0", value: $zoomFactor, formatter: zoomFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("x")
                            .foregroundColor(.secondary)
                    }
                    Stepper(value: $zoomFactor, in: 1...5, step: 0.5) {
                        Text("\(zoomFactor, specifier: "%.1f")x")
                            .foregroundColor(.secondary)
                    }
                    Toggle("フォーカス固定", isOn: $focusLocked)
                }

                Section("撮影後プレビュー") {
                    Toggle("プレビューを表示", isOn: $showRecordingPreview)
                    if showRecordingPreview {
                        Toggle("プレビュー診断表示", isOn: $showPreviewDiagnostics)
                        Toggle("プレビューを自動で閉じる", isOn: $autoClosePreview)
                        Picker("再生速度", selection: $previewPlaybackRate) {
                            Text("0.25x").tag(0.25)
                            Text("0.5x").tag(0.5)
                            Text("1.0x").tag(1.0)
                        }
                        .pickerStyle(.segmented)
                        if autoClosePreview {
                            Picker("ループ回数", selection: $previewLoopCount) {
                                Text("1回").tag(1)
                                Text("2回").tag(2)
                                Text("3回").tag(3)
                                Text("5回").tag(5)
                            }
                        }
                    }
                }

                Section("試し撮影") {
                    Toggle("試し撮影ボタンを表示", isOn: $showTestCaptureButton)
                }
            }
            .navigationTitle("設定")
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

#Preview {
    SettingsView()
}
