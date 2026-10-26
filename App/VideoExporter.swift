import AVFoundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

enum FrameFormat: String, CaseIterable, Identifiable {
    case vertical = "9:16", square = "1:1", landscape = "16:9"
    var id: String { rawValue }
    var ratio: CGFloat { size.width / size.height }
    var size: CGSize {
        switch self {
        case .vertical: return CGSize(width: 720, height: 1280)
        case .square: return CGSize(width: 720, height: 720)
        case .landscape: return CGSize(width: 1280, height: 720)
        }
    }
}
enum VideoExporter {
    static func export(_ url: URL, caption: String, format: FrameFormat, gif: Bool) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ImportError.response }
        let natural = try await track.load(.naturalSize)
        let preferred = try await track.load(.preferredTransform)
        let bounds = CGRect(origin: .zero, size: natural).applying(preferred)
        let size = format.size
        let scale = max(size.width / bounds.width, size.height / bounds.height)
        let transform = preferred.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)).concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: (size.width - bounds.width * scale) / 2, y: (size.height - bounds.height * scale) / 2))
        let composition = AVMutableVideoComposition(asset: asset) { request in
            let image = request.sourceImage.transformed(by: transform).cropped(to: CGRect(origin: .zero, size: size))
            request.finish(with: image, context: nil)
        }
        composition.renderSize = size
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        // Render text into each frame so both MP4 and GIF use the same overlay.
        let overlay = await MainActor.run { () -> CIImage in
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
                let style = NSMutableParagraphStyle(); style.alignment = .center
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 44), .foregroundColor: UIColor.white, .strokeColor: UIColor.black, .strokeWidth: -3, .paragraphStyle: style]
                let rect = CGRect(x: 32, y: size.height - 220, width: size.width - 64, height: 180)
                (caption as NSString).draw(in: rect, withAttributes: attributes)
            }
            return CIImage(cgImage: image.cgImage!)
        }
        let rendered = AVMutableVideoComposition(asset: asset) { request in
            let image = request.sourceImage.transformed(by: transform).cropped(to: CGRect(origin: .zero, size: size))
            request.finish(with: overlay.composited(over: image), context: nil)
        }
        rendered.renderSize = composition.renderSize; rendered.frameDuration = composition.frameDuration
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(gif ? "gif" : "mp4")
        if gif {
            let duration = min(6, try await asset.load(.duration).seconds)
            guard duration.isFinite, duration > 0 else { throw ImportError.response }
            let generator = AVAssetImageGenerator(asset: asset); generator.videoComposition = rendered
            generator.maximumSize = CGSize(width: 480, height: 480)
            guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, Int(ceil(duration * 10)), nil) else { throw ImportError.response }
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for frame in 0..<Int(ceil(duration * 10)) {
                let image = try generator.copyCGImage(at: CMTime(seconds: Double(frame) / 10, preferredTimescale: 600), actualTime: nil)
                CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
            }
            guard CGImageDestinationFinalize(destination) else { throw ImportError.response }
        } else {
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw ImportError.response }
            session.outputURL = output; session.outputFileType = .mp4; session.videoComposition = rendered
            await session.export()
            guard session.status == .completed else { throw session.error ?? ImportError.response }
        }
        return output
    }
}
