import Foundation
import SeleneCore

#if canImport(UIKit)
    import UIKit

    /// Real PDF renderer using `UIGraphicsPDFRenderer`. Availability-guarded so
    /// `swift test` on macOS never needs UIKit; the deterministic
    /// `PlainTextDoctorVisitRenderer` carries the unit tests.
    ///
    /// The drawn content is derived ONLY from the shared
    /// `PlainTextDoctorVisitRenderer.plainText` output, so the PDF can never show
    /// a value the pure document did not carry (invariant #3).
    @available(iOS 16.0, *)
    public struct PDFDoctorVisitRenderer: DoctorVisitRendering {
        private let pageSize: CGSize
        private let margin: CGFloat
        private let textRenderer = PlainTextDoctorVisitRenderer()

        public init(
            pageSize: CGSize = CGSize(width: 612, height: 792), // US Letter, 72 dpi
            margin: CGFloat = 48
        ) {
            self.pageSize = pageSize
            self.margin = margin
        }

        public func render(_ document: DoctorVisitDocument) throws -> Data {
            let body = textRenderer.plainText(document)
            let bounds = CGRect(origin: .zero, size: pageSize)
            let renderer = UIGraphicsPDFRenderer(bounds: bounds)
            return renderer.pdfData { context in
                context.beginPage()
                draw(body, in: bounds)
            }
        }

        private func draw(_ text: String, in bounds: CGRect) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ]
            let inset = bounds.insetBy(dx: margin, dy: margin)
            (text as NSString).draw(in: inset, withAttributes: attributes)
        }
    }
#endif
