import Foundation
import UIKit
import Vision

/// On-device arrow-hole extraction. Vision contour detection finds candidate
/// blobs on the target photo; ArrowTuneCore's deterministic model decides
/// which candidates are arrow holes. All inference happens locally — the
/// photo never leaves the device and is not retained after analysis.
enum TargetPhotoAnalyzer {
    /// Runs contour detection and returns the core model's outcome.
    static func analyze(image: UIImage, expectedArrows: Int) async -> DetectionOutcome {
        guard let cgImage = image.cgImage else {
            return .lowConfidence(reason: "This photo could not be read on device.")
        }
        let candidates = extractCandidates(from: cgImage)
        return ArrowDetectionModel.detect(candidates: candidates, expectedArrows: expectedArrows)
    }

    /// Detects dark, roughly circular contours inside the central target
    /// region and converts them to normalized target coordinates. The target
    /// is assumed centered in the frame with the scoring area filling most of
    /// the shorter side — the in-app framing guide enforces this.
    private static func extractCandidates(from cgImage: CGImage) -> [DetectionCandidate] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.4
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 1024
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let observation = request.results?.first else { return [] }
        let side = Double(min(cgImage.width, cgImage.height))
        var candidates: [DetectionCandidate] = []
        for contour in observation.topLevelContours {
            collect(observation: contour, side: side, into: &candidates, depth: 0)
        }
        return candidates
    }

    private static func collect(observation: VNContour, side: Double,
                                into candidates: inout [DetectionCandidate], depth: Int) {
        guard depth < 3 else { return }
        if observation.childContourCount == 0 {
            let box = observation.normalizedPath.boundingBox
            let width = Double(box.width), height = Double(box.height)
            let radius = max(width, height) / 2.0
            guard radius > 0 else { return }
            // Roundness: contour aspect near 1.0 is circular.
            let aspect = min(width, height) / max(width, height)
            // Vision y-axis is bottom-up; normalize around the frame center so
            // (0,0) is target center and 1.0 is the scoring radius.
            let cx = Double(box.midX) - 0.5
            let cy = Double(box.midY) - 0.5
            let normScale = 1.0 / 0.5 // frame center ± half side == ±1.0
            let darkness = meanDarkness(along: observation.normalizedPath)
            candidates.append(DetectionCandidate(
                x: cx * normScale,
                y: cy * normScale,
                radius: radius * normScale,
                darkness: darkness,
                roundness: max(0, min(1, aspect))
            ))
        }
        for index in 0..<observation.childContourCount {
            if let child = try? observation.childContour(at: index) {
                collect(observation: child, side: side, into: &candidates, depth: depth + 1)
            }
        }
    }

    /// Estimates blob darkness from the contour's aspect-corrected bounding
    /// geometry. Real sampling happens inside Vision's dark-on-light contour
    /// pass, so a detected contour is already dark evidence; the confidence
    /// path still needs a scalar, so we derive one from contour compactness.
    private static func meanDarkness(along path: CGPath) -> Double {
        let box = path.boundingBox
        guard box.width > 0, box.height > 0 else { return 0.4 }
        // Compact filled shapes are darker holes; elongated ones are folds.
        let compactness = min(box.width, box.height) / max(box.width, box.height)
        return 0.35 + 0.55 * Double(compactness)
    }
}
