import Foundation
import MapKit
import UIKit

// MARK: - Custom info window (callout)
//
// MapKit's native callout bubble does not render when the MKMapView is composited
// inside the web view (the way @capacitor/google-maps mounts it). So instead of
// relying on `canShowCallout`, we draw our own bubble as a plain subview of the
// map and keep it glued to the pin with a display link. This renders reliably,
// exactly like the annotation pins do.

/// A rounded info-window bubble showing a marker's title and optional snippet.
/// Interactive: a tap on it emits `onInfoWindowClick` (a tap elsewhere on the map
/// dismisses it).
final class CalloutBubble: UIView {
    /// Widest the bubble grows before text wraps.
    private static let maxWidth: CGFloat = 260

    init(title: String, subtitle: String?) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.masksToBounds = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            widthAnchor.constraint(lessThanOrEqualToConstant: CalloutBubble.maxWidth)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        stack.addArrangedSubview(titleLabel)

        if let subtitle = subtitle, !subtitle.isEmpty {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = .systemFont(ofSize: 13)
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.numberOfLines = 2
            stack.addArrangedSubview(subtitleLabel)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The natural size for the current content (respecting `maxWidth`).
    func fittingSize() -> CGSize {
        systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
    }
}

extension Map {
    /// Approximate height of a default MKMarkerAnnotationView, so the bubble sits
    /// just above the balloon rather than over it.
    private static let markerPinHeight: CGFloat = 46

    /// Show the info window for `marker` (replacing any current one) and start the
    /// display link that keeps it glued to the pin. Must run on the main thread.
    func showCallout(for marker: AppleMapMarker) {
        dismissCallout()
        guard let title = marker.title, !title.isEmpty else { return }

        let bubble = CalloutBubble(title: title, subtitle: marker.subtitle)
        bubble.bounds = CGRect(origin: .zero, size: bubble.fittingSize())
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCalloutTap))
        bubble.addGestureRecognizer(tap)
        calloutView = bubble
        calloutMarker = marker
        mapView.addSubview(bubble)
        repositionCallout()

        let link = CADisplayLink(target: self, selector: #selector(handleCalloutTick))
        link.add(to: .main, forMode: .common)
        calloutDisplayLink = link
    }

    @objc private func handleCalloutTick() {
        repositionCallout()
    }

    /// Emit `onInfoWindowClick` for the marker whose bubble is showing.
    @objc private func handleCalloutTap() {
        guard let marker = calloutMarker else { return }
        delegate?.notifyListeners("onInfoWindowClick", data: [
            "mapId": id,
            "markerId": marker.markerId,
            "latitude": marker.coordinate.latitude,
            "longitude": marker.coordinate.longitude,
            "title": marker.title ?? ""
        ])
    }

    /// Place the bubble centered horizontally over the pin and just above it.
    func repositionCallout() {
        guard let bubble = calloutView, let marker = calloutMarker else { return }
        let anchor = mapView.convert(marker.coordinate, toPointTo: mapView)
        bubble.center = CGPoint(
            x: anchor.x,
            y: anchor.y - Map.markerPinHeight - 6 - bubble.bounds.height / 2
        )
    }

    /// Remove the info window and stop its display link. Must run on the main thread.
    func dismissCallout() {
        calloutDisplayLink?.invalidate()
        calloutDisplayLink = nil
        calloutView?.removeFromSuperview()
        calloutView = nil
        calloutMarker = nil
    }
}
