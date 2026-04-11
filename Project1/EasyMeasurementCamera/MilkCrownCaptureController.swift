//
//  MilkCrownCaptureController.swift
//  EasyShareCamera
//
//  ミルククラウン撮影の制御ロジック
//

import Foundation
import AVFoundation
import Combine

/// 撮影状態
enum CaptureState: Equatable {
    case idle              // 待機中
    case armed             // 準備完了（検知待ち）
    case triggered         // トリガー検知
    case recording         // 録画中
    case completed         // 完了
    case error(String)     // エラー
}

/// ミルククラウン撮影設定
struct MilkCrownCaptureSettings {
    /// 水滴の落下高さ（メートル）
    var dropHeight: Double = 0.3
    
    /// 録画前のバッファ時間（秒）
    var preBufferDuration: Double = 2.0
    
    /// 録画後のバッファ時間（秒）
    var postBufferDuration: Double = 2.0
    
    /// フレームレート（fps）
    var frameRate: Int32 = 240
    
    /// 赤色LED検知の遅延時間（秒）
    var ledDetectionDelay: Double = 0.0
    
    /// 計算された落下時間（秒）
    var calculatedDropTime: Double {
        // 自由落下の式: t = sqrt(2h/g)
        let gravity = 9.81  // m/s²
        return sqrt(2.0 * dropHeight / gravity)
    }
    
    /// 総録画時間（秒）
    var totalRecordingDuration: Double {
        return preBufferDuration + postBufferDuration
    }
}

/// ミルククラウン撮影コントローラー
class MilkCrownCaptureController: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var state: CaptureState = .idle
    @Published var settings: MilkCrownCaptureSettings = MilkCrownCaptureSettings()
    @Published var recordingProgress: Double = 0.0
    @Published var detectionConfidence: Float = 0.0
    
    // MARK: - Properties
    
    private var redLightDetector = RedLightDetector()
    private var triggerTime: Date?
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    
    // MARK: - Initializer
    
    init() {
        setupRedLightDetector()
    }
    
    // MARK: - Public Methods
    
    /// 撮影を準備（Armed状態に移行）
    func arm() {
        switch state {
        case .idle, .completed, .error:
            break
        default:
            print("⚠️ [MilkCrownController] Cannot arm from current state: \(state)")
            return
        }
        
        redLightDetector.reset()
        redLightDetector.isEnabled = true
        triggerTime = nil
        recordingStartTime = nil
        recordingProgress = 0.0
        
        DispatchQueue.main.async {
            self.state = .armed
        }
        
        print("✅ [MilkCrownController] Armed and ready for trigger")
    }
    
    /// 撮影をキャンセル
    func disarm() {
        redLightDetector.isEnabled = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async {
            self.state = .idle
            self.recordingProgress = 0.0
        }
        
        print("🛑 [MilkCrownController] Disarmed")
    }
    
    /// サンプルバッファを処理（赤色検知）
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard state == .armed else { return }
        
        if let result = redLightDetector.detectRedLight(from: sampleBuffer) {
            DispatchQueue.main.async {
                self.detectionConfidence = result.confidence
            }
            
            if result.isDetected {
                handleTrigger(at: Date())
            }
        }
    }
    
    /// 録画開始コールバック（外部から呼ばれる）
    func onRecordingStarted() {
        guard state == .triggered else { return }
        
        recordingStartTime = Date()
        
        DispatchQueue.main.async {
            self.state = .recording
        }
        
        // 録画進捗を監視
        startRecordingProgressTimer()
        
        print("🎬 [MilkCrownController] Recording started")
    }
    
    /// 録画完了コールバック（外部から呼ばれる）
    func onRecordingCompleted(url: URL) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async {
            self.state = .completed
            self.recordingProgress = 1.0
        }
        
        print("✅ [MilkCrownController] Recording completed: \(url.lastPathComponent)")
    }
    
    /// エラーコールバック
    func onError(_ message: String) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        redLightDetector.isEnabled = false
        
        DispatchQueue.main.async {
            self.state = .error(message)
        }
        
        print("❌ [MilkCrownController] Error: \(message)")
    }
    
    /// 物理計算情報を取得
    func getPhysicsInfo() -> String {
        let dropTime = settings.calculatedDropTime
        let totalTime = settings.totalRecordingDuration
        let frameCount = Int(Double(settings.frameRate) * totalTime)
        
        return """
        落下高さ: \(String(format: "%.2f", settings.dropHeight))m
        落下時間: \(String(format: "%.3f", dropTime))秒 (\(Int(dropTime * 1000))ms)
        録画時間: \(String(format: "%.1f", totalTime))秒
        フレームレート: \(settings.frameRate)fps
        総フレーム数: \(frameCount)フレーム
        """
    }
    
    // MARK: - Private Methods
    
    private func setupRedLightDetector() {
        redLightDetector.detectionThreshold = 0.7
        redLightDetector.redSelectivity = 0.3
        redLightDetector.minimumBrightness = 0.4
        
        redLightDetector.onRedLightDetected = { _ in
            // このコールバックは processSampleBuffer 内で既に処理されている
        }
    }
    
    private func handleTrigger(at time: Date) {
        triggerTime = time
        redLightDetector.isEnabled = false  // 一度検知したら無効化
        
        DispatchQueue.main.async {
            self.state = .triggered
        }
        
        print("🔴 [MilkCrownController] TRIGGER DETECTED at \(time)")
        print("📊 [MilkCrownController] Physics: drop time = \(String(format: "%.3f", settings.calculatedDropTime))s")
    }
    
    private func startRecordingProgressTimer() {
        let totalDuration = settings.totalRecordingDuration
        let updateInterval = 0.1  // 100ms ごとに更新
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.recordingStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / totalDuration)
            
            DispatchQueue.main.async {
                self.recordingProgress = progress
            }
        }
    }
}
