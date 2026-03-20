import Foundation
import AVFoundation

// MARK: - Focus Mode

enum FocusMode: String, CaseIterable, Identifiable {
    case locked = "Locked"
    case autoFocus = "Auto"
    case continuousAutoFocus = "Continuous"
    case manual = "Manual"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .locked: return "lock.fill"
        case .autoFocus: return "camera.metering.center.weighted"
        case .continuousAutoFocus: return "camera.metering.matrix"
        case .manual: return "slider.horizontal.3"
        }
    }
}

// MARK: - Exposure Mode

enum ExposureMode: String, CaseIterable, Identifiable {
    case locked = "Locked"
    case autoExpose = "Auto"
    case continuousAutoExposure = "Continuous"
    case manual = "Manual"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .locked: return "lock.fill"
        case .autoExpose: return "sun.max"
        case .continuousAutoExposure: return "sun.max.fill"
        case .manual: return "slider.horizontal.3"
        }
    }
}

// MARK: - White Balance Mode

enum WhiteBalanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case locked = "Locked"
    case daylight = "Daylight"
    case cloudy = "Cloudy"
    case tungsten = "Tungsten"
    case fluorescent = "Fluorescent"
    case flash = "Flash"
    case shade = "Shade"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .auto: return "wand.and.rays"
        case .locked: return "lock.fill"
        case .daylight: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .tungsten: return "lightbulb.fill"
        case .fluorescent: return "light.strip.2"
        case .flash: return "bolt.fill"
        case .shade: return "building.fill"
        }
    }
    
    var temperatureAndTint: (temperature: Float, tint: Float) {
        switch self {
        case .auto, .locked: return (5500, 0)
        case .daylight: return (5500, 0)
        case .cloudy: return (6500, 0)
        case .tungsten: return (3200, 0)
        case .fluorescent: return (4000, -10)
        case .flash: return (5500, 0)
        case .shade: return (7500, 0)
        }
    }
}

// MARK: - Camera Filter

enum CameraFilter: String, CaseIterable, Identifiable {
    case none = "None"
    case vivid = "Vivid"
    case vividWarm = "Vivid Warm"
    case vividCool = "Vivid Cool"
    case dramatic = "Dramatic"
    case dramaticWarm = "Dramatic Warm"
    case dramaticCool = "Dramatic Cool"
    case mono = "Mono"
    case noir = "Noir"
    case silvertone = "Silvertone"
    case sepia = "Sepia"
    case chrome = "Chrome"
    case fade = "Fade"
    case instant = "Instant"
    case process = "Process"
    case transfer = "Transfer"
    case cinematic = "Cinematic"
    
    var id: String { rawValue }
    
    var ciFilterName: String? {
        switch self {
        case .none: return nil
        case .vivid: return "CIPhotoEffectChrome"
        case .vividWarm: return "CIPhotoEffectInstant"
        case .vividCool: return "CIPhotoEffectProcess"
        case .dramatic: return "CIPhotoEffectNoir"
        case .dramaticWarm: return "CIPhotoEffectTransfer"
        case .dramaticCool: return "CIPhotoEffectFade"
        case .mono: return "CIPhotoEffectMono"
        case .noir: return "CIPhotoEffectNoir"
        case .silvertone: return "CIPhotoEffectTonal"
        case .sepia: return "CISepiaTone"
        case .chrome: return "CIPhotoEffectChrome"
        case .fade: return "CIPhotoEffectFade"
        case .instant: return "CIPhotoEffectInstant"
        case .process: return "CIPhotoEffectProcess"
        case .transfer: return "CIPhotoEffectTransfer"
        case .cinematic: return nil  // Custom implementation
        }
    }
}

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case low = "720p"
    case medium = "1080p"
    case high = "1080p HDR"
    case ultra = "4K"
    
    var id: String { rawValue }
    
    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .low: return .hd1280x720
        case .medium: return .hd1920x1080
        case .high: return .hd1920x1080
        case .ultra: return .hd4K3840x2160
        }
    }
}

// MARK: - Camera Permission

enum CameraPermission {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Camera Error

enum CameraError: Error, LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case microphoneUnavailable
    case setupFailed(Error)
    case recordingFailed(Error)
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .cameraUnavailable:
            return "Camera is not available"
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .setupFailed(let error):
            return "Camera setup failed: \(error.localizedDescription)"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Camera Settings

struct CameraSettings {
    var focusMode: FocusMode = .continuousAutoFocus
    var focusPosition: Float = 0.5
    
    var exposureMode: ExposureMode = .continuousAutoExposure
    var exposureCompensation: Float = 0
    var iso: Float = 100
    var shutterSpeed: Double = 1.0/60.0
    
    var whiteBalanceMode: WhiteBalanceMode = .auto
    var colorTemperature: Float = 5500
    var tint: Float = 0
    
    var depthEnabled: Bool = false
    var simulatedAperture: Float = 2.8
    
    var activeFilter: CameraFilter = .none
    var videoQuality: VideoQuality = .medium
    var stabilizationEnabled: Bool = true
    
    // Ranges for UI sliders
    static let isoRange: ClosedRange<Float> = 50...3200
    static let shutterSpeedRange: ClosedRange<Double> = 1.0/8000.0...1.0/2.0
    static let exposureCompensationRange: ClosedRange<Float> = -3...3
    static let apertureRange: ClosedRange<Float> = 1.4...16
    static let temperatureRange: ClosedRange<Float> = 2500...10000
    static let tintRange: ClosedRange<Float> = -150...150
}
