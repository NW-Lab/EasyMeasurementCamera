//
//  CameraManager.swift
//  EasyShareCamera
//
//  Created by EasyShareCamera on 2025/10/13.
//

import Foundation
import AVFoundation
import SwiftUI
import Photos
import Combine

/// カメラの操作を管理するクラス
class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var alertError: AlertError?
    @Published var capturedImage: UIImage?
    
    // MARK: - Private Properties
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var settings: CameraSettings
    
    // MARK: - Computed Properties
    var captureDevice: AVCaptureDevice? {
        return videoDeviceInput?.device
    }
    
    // MARK: - Initializer
    init(settings: CameraSettings) {
        self.settings = settings
        super.init()
        configure()
    }
    
    // MARK: - Public Methods
    
    /// カメラの初期設定
    func configure() {
        // カメラ権限があるときのみキャプチャセッションを構築する
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 [CameraManager] configure() - authorization status: \(status.rawValue)")
        switch status {
        case .authorized:
            print("🎥 [CameraManager] Already authorized, setting up session")
            DispatchQueue.main.async { self.hasPermission = true }
            sessionQueue.async { self.configureCaptureSession() }
        case .notDetermined:
            print("🎥 [CameraManager] Requesting camera access...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🎥 [CameraManager] Access granted: \(granted)")
                DispatchQueue.main.async {
                    self.hasPermission = granted
                }
                if granted {
                    self.sessionQueue.async { self.configureCaptureSession() }
                }
            }
        case .denied, .restricted:
            print("🎥 [CameraManager] Camera access denied or restricted")
            DispatchQueue.main.async { self.hasPermission = false }
        @unknown default:
            print("🎥 [CameraManager] Unknown authorization status")
            DispatchQueue.main.async { self.hasPermission = false }
        }
    }
    
    /// カメラセッションを開始
    func startSession() {
        print("🎥 [CameraManager] startSession() called")
        sessionQueue.async {
            if !self.captureSession.isRunning {
                print("🎥 [CameraManager] Starting capture session...")
                self.captureSession.startRunning()
                
                // セッション開始後にズーム倍率キャッシュをリセット
                self.resetZoomFactorsCache()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    print("🎥 [CameraManager] Session is now running")
                }
            } else {
                print("🎥 [CameraManager] Session already running")
            }
        }
    }
    
    /// カメラセッションを停止
    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    /// 写真を撮影
    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        
        // フラッシュ設定
        if captureDevice?.hasFlash == true {
            photoSettings.flashMode = settings.flashMode
        }
        
        // 高品質設定: target は iOS 17 なので maxPhotoDimensions を使う
        let maxDims = photoOutput.maxPhotoDimensions
        photoSettings.maxPhotoDimensions = maxDims
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    /// 動画録画を開始/停止
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// 設定をカメラデバイスに適用
    func applyCameraSettings() {
        guard let device = captureDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                // ISO設定
                if device.isExposureModeSupported(.custom) {
                    let exposureDuration = CMTime(seconds: self.settings.exposureDuration, preferredTimescale: 1000000)
                    device.setExposureModeCustom(duration: exposureDuration, iso: self.settings.isoValue, completionHandler: nil)
                }
                
                // フォーカス設定
                if device.isFocusModeSupported(self.settings.focusMode) {
                    device.focusMode = self.settings.focusMode
                    if self.settings.focusMode == .locked {
                        device.setFocusModeLocked(lensPosition: self.settings.lensPosition, completionHandler: nil)
                    }
                }
                
                // ホワイトバランス設定
                if device.isWhiteBalanceModeSupported(self.settings.whiteBalanceMode) {
                    device.whiteBalanceMode = self.settings.whiteBalanceMode
                }
                
                // ズーム設定
                device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, 
                                           min(device.maxAvailableVideoZoomFactor, self.settings.zoomFactor))
                
                device.unlockForConfiguration()
                
                // 設定を保存
                DispatchQueue.main.async {
                    self.settings.saveSettings()
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.alertError = AlertError(message: "カメラ設定の適用に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// ズーム操作
    func zoom(by factor: CGFloat) {
        guard let device = captureDevice else { return }
        
        // iOS 18: 0.5x の特別処理
        var targetZoomFactor = factor
        if #available(iOS 18.0, *) {
            if factor == 0.5 && device.isVirtualDevice {
                // iOS 18 では minAvailableVideoZoomFactor が 1.0 でも、実際には 0.5x が可能
                print("🎥 [CameraManager] iOS 18: Attempting 0.5x zoom on virtual device")
                targetZoomFactor = 0.5
            }
        }
        
        // 実用的な範囲に制限（最大10倍まで、0.5x は特別許可）
        let maxPracticalZoom = min(device.maxAvailableVideoZoomFactor, 10.0)
        let minZoomFactor = (targetZoomFactor == 0.5) ? 0.5 : device.minAvailableVideoZoomFactor
        let newZoomFactor = max(minZoomFactor,
                               min(maxPracticalZoom, targetZoomFactor))
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                // iOS 18 での 0.5x 問題対策：まず try-catch で安全に実行
                var actualZoomFactor = newZoomFactor
                do {
                    device.videoZoomFactor = newZoomFactor
                    print("🎥 [CameraManager] ✅ Zoom set to: \(newZoomFactor)x (requested: \(factor)x)")
                } catch {
                    // 0.5x が失敗した場合、minZoom に設定してフォールバック
                    if newZoomFactor < device.minAvailableVideoZoomFactor {
                        actualZoomFactor = device.minAvailableVideoZoomFactor
                        device.videoZoomFactor = actualZoomFactor
                        print("🎥 [CameraManager] ⚠️ \(newZoomFactor)x failed, fallback to \(actualZoomFactor)x")
                        print("🎥 [CameraManager] Error: \(error.localizedDescription)")
                    } else {
                        throw error // 他のエラーは再スローする
                    }
                }
                
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.settings.zoomFactor = actualZoomFactor
                    self.settings.saveSettings()
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertError = AlertError(message: "ズーム操作に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // キャッシュされたズーム倍率
    private var cachedZoomFactors: [CGFloat]?
    
    /// ズーム倍率キャッシュをリセット（セッション変更時など）
    func resetZoomFactorsCache() {
        cachedZoomFactors = nil
        print("🎥 [CameraManager] Zoom factors cache reset")
    }
    
    /// 利用可能なズーム倍率のリストを取得（キャッシュ版）
    func getAvailableZoomFactors() -> [CGFloat] {
        // 既にキャッシュされている場合はそれを返す
        if let cached = cachedZoomFactors {
            return cached
        }
        
        guard let device = captureDevice else { 
            cachedZoomFactors = [1.0]
            return [1.0] 
        }
        
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0) // 実用的な最大値を10倍に制限
        
        print("🎥 [CameraManager] Device: \(device.localizedName)")
        print("🎥 [CameraManager] Device type: \(device.deviceType.rawValue)")
        print("🎥 [CameraManager] Zoom range: \(minZoom) ~ \(device.maxAvailableVideoZoomFactor) (limited to \(maxZoom))")
        print("🎥 [CameraManager] Is virtual device: \(device.isVirtualDevice)")
        if #available(iOS 13.0, *) {
            print("🎥 [CameraManager] Constituent devices: \(device.constituentDevices.count)")
        }
        
        // iOS 18 では、仮想デバイスでも 0.5x が minZoomFactor に反映されない問題があるため
        // 強制的に 0.5x を含める（iOS 18 対応）
        var candidates: [CGFloat] = []
        
        if #available(iOS 18.0, *) {
            // iOS 18: Virtual Device または UltraWideCamera の場合に 0.5x を追加
            if device.isVirtualDevice {
                // Virtual Device の場合：constituent devices をチェック
                let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
                if hasUltraWide {
                    candidates = [0.5, 1.0, 3.0]
                    print("🎥 [CameraManager] iOS 18: Virtual device with ultra-wide support")
                } else {
                    candidates = [1.0, 3.0]
                    print("🎥 [CameraManager] iOS 18: Virtual device without ultra-wide")
                }
            } else if device.deviceType == .builtInUltraWideCamera {
                // Physical UltraWideCamera の場合（フォールバック用）
                candidates = [0.5, 1.0, 3.0]
                print("🎥 [CameraManager] iOS 18: Physical ultra-wide camera (fallback mode)")
            } else {
                candidates = [1.0, 3.0]
                print("🎥 [CameraManager] iOS 18: Regular camera without ultra-wide")
            }
        } else {
            // iOS 17 以前: 従来通り
            candidates = [0.5, 1.0, 3.0]
        }
        
        // デバイスがサポートする範囲内の倍率のみを返す
        let availableFactors = candidates.filter { factor in
            // iOS 18 での 0.5x 特別処理：Virtual Device または UltraWideCamera なら 0.5x を許可
            if #available(iOS 18.0, *), factor == 0.5 {
                if device.isVirtualDevice {
                    let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
                    if hasUltraWide {
                        print("🎥 [CameraManager] ✅ \(factor)x is ALLOWED for iOS 18 virtual device with ultra-wide")
                        return true
                    }
                } else if device.deviceType == .builtInUltraWideCamera {
                    print("🎥 [CameraManager] ✅ \(factor)x is ALLOWED for iOS 18 physical ultra-wide camera")
                    return true
                }
            }
            
            let isSupported = factor >= (minZoom - 0.01) && factor <= (maxZoom + 0.01)  // 少し余裕を持たせる
            if isSupported {
                print("🎥 [CameraManager] ✅ \(factor)x is supported")
            } else {
                print("🎥 [CameraManager] ❌ \(factor)x is not supported (range: \(minZoom)~\(maxZoom))")
            }
            return isSupported
        }.sorted()
        
        print("🎥 [CameraManager] Final available zoom factors: \(availableFactors)")
        
        // キャッシュに保存
        cachedZoomFactors = availableFactors
        
        return availableFactors
    }
    
    /// フォーカスポイント設定
    func setFocusPoint(_ point: CGPoint) {
        guard let device = captureDevice else { return }
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.alertError = AlertError(message: "フォーカス設定に失敗しました: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Private Methods
private extension CameraManager {
    
    /// カメラ権限をチェック
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                }
            }
        case .denied, .restricted:
            hasPermission = false
        @unknown default:
            hasPermission = false
        }
    }
    
    /// キャプチャセッションの設定
    func configureCaptureSession() {
        print("🎥 [CameraManager] configureCaptureSession() - starting configuration")
        captureSession.beginConfiguration()
        
        // セッション品質設定（超広角アクセスのため inputPriority を試す）
        if captureSession.canSetSessionPreset(.inputPriority) {
            captureSession.sessionPreset = .inputPriority
            print("🎥 [CameraManager] Session preset set to: inputPriority (for ultra-wide access)")
        } else if captureSession.canSetSessionPreset(settings.videoQuality) {
            captureSession.sessionPreset = settings.videoQuality
            print("🎥 [CameraManager] Session preset set to: \(settings.videoQuality.rawValue)")
        }
        
        // ビデオデバイス設定: iOS 18対応（Virtual Device を優先）
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(iOS 18.0, *) {
            deviceTypes = [
                .builtInTripleCamera,      // iOS 18: Virtual Device を優先（安定した超広角アクセス）
                .builtInDualWideCamera,    // iPhone 13, 14 など
                .builtInUltraWideCamera,   // Physical Device は後回し
                .builtInDualCamera,        // iPhone 12 Pro など
                .builtInWideAngleCamera    // 古い機種用
            ]
        } else {
            deviceTypes = [
                .builtInUltraWideCamera,   // iOS 17以前: Physical Device を優先
                .builtInTripleCamera,      // iPhone 13 Pro, 14 Pro など
                .builtInDualWideCamera,    // iPhone 13, 14 など
                .builtInDualCamera,        // iPhone 12 Pro など
                .builtInWideAngleCamera    // 古い機種用
            ]
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        // 利用可能なデバイスを全てログ出力
        print("🎥 [CameraManager] Available devices:")
        for (index, device) in discoverySession.devices.enumerated() {
            print("🎥 [CameraManager] Device \(index): \(device.localizedName) (type: \(device.deviceType.rawValue))")
            print("🎥 [CameraManager] - Zoom range: \(device.minAvailableVideoZoomFactor) ~ \(device.maxAvailableVideoZoomFactor)")
        }
        
        guard let videoDevice = discoverySession.devices.first else {
            print("🎥 [CameraManager] ❌ Failed to get video device")
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "カメラデバイスが見つかりません")
            }
            return
        }
        
        print("🎥 [CameraManager] Got video device: \(videoDevice.localizedName) (type: \(videoDevice.deviceType.rawValue))")
        print("🎥 [CameraManager] Zoom range: \(videoDevice.minAvailableVideoZoomFactor) ~ \(videoDevice.maxAvailableVideoZoomFactor)")
        print("🎥 [CameraManager] Device capabilities:")
        print("🎥 [CameraManager] - hasFlash: \(videoDevice.hasFlash)")
        print("🎥 [CameraManager] - hasTorch: \(videoDevice.hasTorch)")
        print("🎥 [CameraManager] - isVirtualDevice: \(videoDevice.isVirtualDevice)")
        if #available(iOS 13.0, *) {
            print("🎥 [CameraManager] - constituentDevices count: \(videoDevice.constituentDevices.count)")
            for (index, device) in videoDevice.constituentDevices.enumerated() {
                print("🎥 [CameraManager] - Component \(index): \(device.localizedName) (type: \(device.deviceType.rawValue))")
                print("🎥 [CameraManager] - Component zoom: \(device.minAvailableVideoZoomFactor) ~ \(device.maxAvailableVideoZoomFactor)")
            }
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                print("🎥 [CameraManager] ✅ Video input added successfully")
            } else {
                print("🎥 [CameraManager] ❌ Cannot add video input to session")
            }
        } catch {
            print("🎥 [CameraManager] ❌ Failed to create video input: \(error)")
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "カメラデバイスの設定に失敗しました: \(error.localizedDescription)")
            }
            return
        }
        
        // 写真出力設定
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            print("🎥 [CameraManager] ✅ Photo output added")
            // iOS 17 をターゲットにしているので deprecated なフラグは不要。
            // 最大フォト解像度を参照しておく（将来的な設定に備える）
            _ = photoOutput.maxPhotoDimensions
        }
        
        // 動画出力設定
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            print("🎥 [CameraManager] ✅ Movie output added")
        }
        
        captureSession.commitConfiguration()
        print("🎥 [CameraManager] ✅ Session configuration committed")
        
        // デバイス設定を検証・調整
        settings.validateAndAdjustSettings(for: videoDevice)
        
        // 設定をデバイスに適用
        applyCameraSettings()
    }
    
    /// 動画録画開始
    func startRecording() {
        guard !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsPath.appendingPathComponent("video_\(Date().timeIntervalSince1970).mov")
        
        movieOutput.startRecording(to: videoURL, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    /// 動画録画停止
    func stopRecording() {
        guard isRecording else { return }
        
        movieOutput.stopRecording()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "写真撮影に失敗しました: \(error.localizedDescription)")
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "画像データの生成に失敗しました")
            }
            return
        }
        
        // 写真を保存
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    self.capturedImage = image
                } else {
                    self.alertError = AlertError(message: "写真の保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "動画録画に失敗しました: \(error.localizedDescription)")
            }
            return
        }
        
        // 動画を写真ライブラリに保存
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if !success {
                    self.alertError = AlertError(message: "動画の保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
            
            // 一時ファイルを削除
            try? FileManager.default.removeItem(at: outputFileURL)
        }
    }
}

// MARK: - Supporting Types

struct AlertError: Equatable {
    let message: String
}