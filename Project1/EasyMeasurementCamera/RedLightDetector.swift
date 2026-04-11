//
//  RedLightDetector.swift
//  EasyShareCamera
//
//  ミルククラウン撮影用の赤色LED検知システム
//

import Foundation
import AVFoundation
import CoreImage
import UIKit

/// 赤色LED検知の結果
struct RedLightDetectionResult {
    let isDetected: Bool
    let confidence: Float  // 0.0 ~ 1.0
    let timestamp: CMTime
    let averageRedIntensity: Float
}

/// 赤色LED検知マネージャー
class RedLightDetector: NSObject {
    
    // MARK: - Properties
    
    /// 検知コールバック
    var onRedLightDetected: ((RedLightDetectionResult) -> Void)?
    
    /// 検知の有効/無効
    var isEnabled: Bool = false
    
    /// 検知閾値（0.0 ~ 1.0）
    var detectionThreshold: Float = 0.7
    
    /// 赤色の選択性（他の色との差の最小値）
    var redSelectivity: Float = 0.3
    
    /// 最小輝度閾値
    var minimumBrightness: Float = 0.4
    
    // MARK: - Private Properties
    
    private var lastDetectionTime: CMTime = .zero
    private let detectionCooldown: Double = 0.1  // 100ms のクールダウン
    private let context = CIContext()
    
    // MARK: - Public Methods
    
    /// サンプルバッファから赤色を検知
    func detectRedLight(from sampleBuffer: CMSampleBuffer) -> RedLightDetectionResult? {
        guard isEnabled else { return nil }
        
        // クールダウン期間中は処理をスキップ
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if CMTimeGetSeconds(currentTime - lastDetectionTime) < detectionCooldown {
            return nil
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 画像の中央領域を解析（LED は通常画面中央に配置される）
        let centerRect = getCenterRegion(of: ciImage.extent)
        let croppedImage = ciImage.cropped(to: centerRect)
        
        // RGB値を抽出
        guard let rgbValues = extractAverageRGB(from: croppedImage) else {
            return nil
        }
        
        // 赤色の強度を計算
        let redIntensity = rgbValues.red
        let greenIntensity = rgbValues.green
        let blueIntensity = rgbValues.blue
        
        // 輝度を計算
        let brightness = (redIntensity + greenIntensity + blueIntensity) / 3.0
        
        // 赤色の選択性を計算（赤が他の色より明らかに強いか）
        let redDominance = redIntensity - max(greenIntensity, blueIntensity)
        
        // 検知条件
        let isDetected = redIntensity > detectionThreshold &&
                        redDominance > redSelectivity &&
                        brightness > minimumBrightness
        
        let confidence = min(1.0, (redIntensity + redDominance) / 2.0)
        
        let result = RedLightDetectionResult(
            isDetected: isDetected,
            confidence: confidence,
            timestamp: currentTime,
            averageRedIntensity: redIntensity
        )
        
        if isDetected {
            lastDetectionTime = currentTime
            onRedLightDetected?(result)
            print("🔴 [RedLightDetector] RED LIGHT DETECTED! R:\(redIntensity) G:\(greenIntensity) B:\(blueIntensity) Confidence:\(confidence)")
        }
        
        return result
    }
    
    /// 検知パラメータをリセット
    func reset() {
        lastDetectionTime = .zero
    }
    
    // MARK: - Private Methods
    
    /// 画像の中央領域を取得（全体の50%）
    private func getCenterRegion(of extent: CGRect) -> CGRect {
        let centerX = extent.midX
        let centerY = extent.midY
        let width = extent.width * 0.5
        let height = extent.height * 0.5
        
        return CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }
    
    /// 画像から平均RGB値を抽出
    private func extractAverageRGB(from ciImage: CIImage) -> (red: Float, green: Float, blue: Float)? {
        // CIImage を CGImage に変換
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // ビットマップコンテキストを作成
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // RGB値の合計を計算
        var totalRed: UInt64 = 0
        var totalGreen: UInt64 = 0
        var totalBlue: UInt64 = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            totalRed += UInt64(pixelData[i])
            totalGreen += UInt64(pixelData[i + 1])
            totalBlue += UInt64(pixelData[i + 2])
        }
        
        // 平均値を計算（0.0 ~ 1.0 に正規化）
        let avgRed = Float(totalRed) / Float(pixelCount) / 255.0
        let avgGreen = Float(totalGreen) / Float(pixelCount) / 255.0
        let avgBlue = Float(totalBlue) / Float(pixelCount) / 255.0
        
        return (red: avgRed, green: avgGreen, blue: avgBlue)
    }
}
