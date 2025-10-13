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
        
        let newZoomFactor = max(device.minAvailableVideoZoomFactor,
                               min(device.maxAvailableVideoZoomFactor, factor))
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.settings.zoomFactor = newZoomFactor
                    self.settings.saveSettings()
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertError = AlertError(message: "ズーム操作に失敗しました: \(error.localizedDescription)")
                }
            }
        }
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
        
        // セッション品質設定
        if captureSession.canSetSessionPreset(settings.videoQuality) {
            captureSession.sessionPreset = settings.videoQuality
            print("🎥 [CameraManager] Session preset set to: \(settings.videoQuality.rawValue)")
        }
        
        // ビデオデバイス設定
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("🎥 [CameraManager] ❌ Failed to get video device")
            DispatchQueue.main.async {
                self.alertError = AlertError(message: "カメラデバイスが見つかりません")
            }
            return
        }
        print("🎥 [CameraManager] Got video device: \(videoDevice.localizedName)")
        
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