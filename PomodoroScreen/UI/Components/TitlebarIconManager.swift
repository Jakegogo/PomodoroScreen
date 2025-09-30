import AppKit

final class TitlebarIconManager {
    enum Position { case leading, trailing }

    /// Attach an image from bundle to window titlebar.
    /// - Returns: Created NSTitlebarAccessoryViewController if success
    @discardableResult
    static func attachIcon(to window: NSWindow,
                           resourceName: String,
                           ext: String = "svg",
                           size: NSSize = NSSize(width: 20, height: 20),
                           position: Position = .trailing) -> NSTitlebarAccessoryViewController? {
        guard let url = findResourceURL(named: resourceName, ext: ext),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = false

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.imageScaling = .scaleProportionallyDown
        imageView.image = image

        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = imageView
        accessory.layoutAttribute = (position == .leading) ? .leading : .trailing
        window.addTitlebarAccessoryViewController(accessory)
        return accessory
    }

    /// Try common bundle locations to find a resource URL
    private static func findResourceURL(named name: String, ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        let candidates = ["image/\(name)", "Resources/image/\(name)"]
        for cand in candidates {
            if let url = Bundle.main.url(forResource: cand, withExtension: ext) { return url }
        }
        if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
            return urls.first { $0.lastPathComponent.lowercased() == "\(name).\(ext)" }
        }
        return nil
    }

    /// Create a centered title view (icon + text) in the titlebar and hide the system title.
    /// Returns the container stack view for later adjustments if needed.
    @discardableResult
    static func setCenteredTitle(window: NSWindow,
                                 text: String,
                                 iconResource: String,
                                 ext: String = "svg",
                                 iconSize: NSSize = NSSize(width: 20, height: 20),
                                 font: NSFont = NSFont.systemFont(ofSize: 13, weight: .semibold),
                                 color: NSColor = .labelColor) -> NSStackView? {
        guard let titlebarView = window.standardWindowButton(.closeButton)?.superview else { return nil }
        window.titleVisibility = .hidden

        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .centerY
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.widthAnchor.constraint(equalToConstant: iconSize.width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: iconSize.height).isActive = true
        if let url = findResourceURL(named: iconResource, ext: ext), let image = NSImage(contentsOf: url) {
            imageView.image = image
        }

        let titleLabel = NSTextField(labelWithString: text)
        titleLabel.font = font
        titleLabel.textColor = color

        container.addArrangedSubview(imageView)
        container.addArrangedSubview(titleLabel)
        titlebarView.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor)
        ])

        return container
    }
}


