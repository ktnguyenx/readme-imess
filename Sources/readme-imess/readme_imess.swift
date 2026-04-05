import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CLIError: LocalizedError {
	case usage(String)
	case invalidConfig(String)
	case fileExists(String)
	case renderFailed(String)

	var errorDescription: String? {
		switch self {
		case .usage(let message):
			return message
		case .invalidConfig(let message):
			return message
		case .fileExists(let path):
			return "Refusing to overwrite existing file at \(path)."
		case .renderFailed(let message):
			return message
		}
	}
}

enum BubbleSide: String, Codable {
	case left
	case right
}

struct ChatConfig: Codable {
	var title: String?
	var description: String?
	var animationSeconds: Double?
	var canvas: CanvasConfig?
	var theme: ThemeConfig?
	var typingIndicator: TypingIndicatorConfig?
	var gif: GIFConfig?
	var messages: [MessageConfig]
}

struct CanvasConfig: Codable {
	var width: Double?
	var height: Double?
	var sideInset: Double?
	var topInset: Double?
	var bottomInset: Double?
	var bubbleGap: Double?
	var maxBubbleWidthRatio: Double?
	var fontSize: Double?
}

struct ThemeConfig: Codable {
	var incomingBubbleColor: String?
	var outgoingBubbleColor: String?
	var incomingTextColor: String?
	var outgoingTextColor: String?
	var statusColor: String?
	var backgroundColor: String?
}

struct TypingIndicatorConfig: Codable {
	var enabled: Bool?
	var side: BubbleSide?
}

struct GIFConfig: Codable {
	var fps: Int?
	var scale: Double?
	var loopCount: Int?
}

struct MessageConfig: Codable {
	var side: BubbleSide
	var text: String
	var status: String?
	var bubbleColor: String?
	var textColor: String?
}

struct ResolvedTheme {
	let incomingBubbleColor: String
	let outgoingBubbleColor: String
	let incomingTextColor: String
	let outgoingTextColor: String
	let statusColor: String
	let backgroundColor: String?
}

struct ResolvedGIFConfig {
	let fps: Int
	let scale: Double
	let loopCount: Int
}

struct ResolvedMessage {
	let side: BubbleSide
	let text: String
	let status: String?
	let bubbleColor: String
	let textColor: String
}

struct ResolvedChatConfig {
	let title: String
	let description: String
	let animationSeconds: Double
	let canvasWidth: Double
	let requestedCanvasHeight: Double?
	let sideInset: Double
	let topInset: Double
	let bottomInset: Double
	let bubbleGap: Double
	let maxBubbleWidthRatio: Double
	let fontSize: Double
	let typingEnabled: Bool
	let typingSide: BubbleSide
	let theme: ResolvedTheme
	let gif: ResolvedGIFConfig
	let messages: [ResolvedMessage]
}

struct BubbleAnimation {
	let fadeInStart: Double
	let visibleStart: Double
	let holdEnd: Double
	let fadeOutEnd: Double
}

struct BubbleLayout {
	let id: Int
	let side: BubbleSide
	let lines: [String]
	let x: Double
	let y: Double
	let width: Double
	let height: Double
	let textLeadingInset: Double
	let textTopInset: Double
	let fillColor: String
	let textColor: String
	let status: String?
	let statusWidth: Double
	let animation: BubbleAnimation
	let statusAnimation: BubbleAnimation?
}

struct TypingIndicatorLayout {
	let side: BubbleSide
	let x: Double
	let y: Double
	let width: Double
	let height: Double
	let bubbleColor: String
	let dotColor: String
	let animation: BubbleAnimation
}

struct ChatLayout {
	let canvasWidth: Double
	let canvasHeight: Double
	let lineHeight: Double
	let fontAscender: Double
	let messages: [BubbleLayout]
	let typingIndicator: TypingIndicatorLayout?
}

struct BubbleRenderState {
	let opacity: Double
	let translateY: Double
	let scale: Double
}

extension ChatConfig {
	func resolved(fallbackName: String) throws -> ResolvedChatConfig {
		guard !messages.isEmpty else {
			throw CLIError.invalidConfig("Config must include at least one message.")
		}

		let readableName = makeReadableName(from: fallbackName)
		let resolvedTheme = ResolvedTheme(
			incomingBubbleColor: theme?.incomingBubbleColor ?? "#E9E9EB",
			outgoingBubbleColor: theme?.outgoingBubbleColor ?? "#509DF6",
			incomingTextColor: theme?.incomingTextColor ?? "#111111",
			outgoingTextColor: theme?.outgoingTextColor ?? "#FFFFFF",
			statusColor: theme?.statusColor ?? "#7D7D82",
			backgroundColor: theme?.backgroundColor
		)

		let resolvedMessages = messages.map { message in
			ResolvedMessage(
				side: message.side,
				text: message.text,
				status: message.status,
				bubbleColor: message.bubbleColor ?? (message.side == .left ? resolvedTheme.incomingBubbleColor : resolvedTheme.outgoingBubbleColor),
				textColor: message.textColor ?? (message.side == .left ? resolvedTheme.incomingTextColor : resolvedTheme.outgoingTextColor)
			)
		}

		return ResolvedChatConfig(
			title: title ?? "Animated iMessage-style README conversation for \(readableName)",
			description: description ?? "A custom animated iMessage-style README conversation with \(resolvedMessages.count) messages.",
			animationSeconds: max(animationSeconds ?? 12.0, 1.0),
			canvasWidth: max(canvas?.width ?? 960, 400),
			requestedCanvasHeight: canvas?.height,
			sideInset: max(canvas?.sideInset ?? 88, 24),
			topInset: max(canvas?.topInset ?? 34, 16),
			bottomInset: max(canvas?.bottomInset ?? 34, 16),
			bubbleGap: max(canvas?.bubbleGap ?? 26, 12),
			maxBubbleWidthRatio: min(max(canvas?.maxBubbleWidthRatio ?? 0.72, 0.35), 0.9),
			fontSize: max(canvas?.fontSize ?? 22, 16),
			typingEnabled: typingIndicator?.enabled ?? true,
			typingSide: typingIndicator?.side ?? .left,
			theme: resolvedTheme,
			gif: ResolvedGIFConfig(
				fps: max(gif?.fps ?? 12, 1),
				scale: max(gif?.scale ?? 1.0, 0.2),
				loopCount: max(gif?.loopCount ?? 0, 0)
			),
			messages: resolvedMessages
		)
	}
}

func makeReadableName(from fileStem: String) -> String {
	let separators = CharacterSet(charactersIn: "-_")
	let words = fileStem
		.components(separatedBy: separators)
		.filter { !$0.isEmpty }
	if words.isEmpty {
		return "Your Profile"
	}

	return words
		.map { word in
			guard let first = word.first else { return word }
			return String(first).uppercased() + word.dropFirst()
		}
		.joined(separator: " ")
}

func textWidth(_ text: String, font: NSFont) -> Double {
	let attributes: [NSAttributedString.Key: Any] = [.font: font]
	return ceil(Double((text as NSString).size(withAttributes: attributes).width))
}

func wrapText(_ text: String, maxWidth: Double, font: NSFont) -> [String] {
	let paragraphs = text.components(separatedBy: .newlines)
	var wrappedLines: [String] = []

	for paragraph in paragraphs {
		let words = paragraph.split(whereSeparator: \.isWhitespace).map(String.init)
		if words.isEmpty {
			wrappedLines.append("")
			continue
		}

		var currentLine = ""

		for word in words {
			let candidate = currentLine.isEmpty ? word : "\(currentLine) \(word)"
			if textWidth(candidate, font: font) <= maxWidth {
				currentLine = candidate
				continue
			}

			if !currentLine.isEmpty {
				wrappedLines.append(currentLine)
			}

			if textWidth(word, font: font) <= maxWidth {
				currentLine = word
				continue
			}

			var fragment = ""
			for character in word {
				let nextFragment = fragment + String(character)
				if textWidth(nextFragment, font: font) <= maxWidth || fragment.isEmpty {
					fragment = nextFragment
				} else {
					wrappedLines.append(fragment)
					fragment = String(character)
				}
			}

			currentLine = fragment
		}

		if !currentLine.isEmpty {
			wrappedLines.append(currentLine)
		}
	}

	return wrappedLines.isEmpty ? [""] : wrappedLines
}

func xmlEscaped(_ text: String) -> String {
	text
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
		.replacingOccurrences(of: "\"", with: "&quot;")
}

func percentage(_ value: Double) -> String {
	String(format: "%.2f", value * 100)
}

func bubbleAnimationKeyframes(name: String, animation: BubbleAnimation, entryTranslate: Double = 12, exitTranslate: Double = 8, entryScale: Double = 0.985, exitScale: Double = 0.99) -> String {
	"""
	    @keyframes \(name) {
	      0%, \(percentage(animation.fadeInStart))% {
	        opacity: 0;
	        transform: translateY(\(entryTranslate)px) scale(\(entryScale));
	      }

	      \(percentage(animation.visibleStart))%, \(percentage(animation.holdEnd))% {
	        opacity: 1;
	        transform: translateY(0) scale(1);
	      }

	      \(percentage(animation.fadeOutEnd))%, 100% {
	        opacity: 0;
	        transform: translateY(\(exitTranslate)px) scale(\(exitScale));
	      }
	    }
	"""
}

func statusAnimationKeyframes(name: String, animation: BubbleAnimation) -> String {
	"""
	    @keyframes \(name) {
	      0%, \(percentage(animation.fadeInStart))% {
	        opacity: 0;
	        transform: translateY(6px) scale(0.88);
	      }

	      \(percentage(animation.visibleStart))% {
	        opacity: 1;
	        transform: translateY(0) scale(1.05);
	      }

	      \(percentage(animation.holdEnd))% {
	        opacity: 1;
	        transform: translateY(0) scale(1);
	      }

	      \(percentage(animation.fadeOutEnd))%, 100% {
	        opacity: 0;
	        transform: translateY(4px) scale(0.95);
	      }
	    }
	"""
}

func renderState(for progress: Double, animation: BubbleAnimation, entryTranslate: Double = 12, exitTranslate: Double = 8, entryScale: Double = 0.985, exitScale: Double = 0.99) -> BubbleRenderState {
	if progress < animation.fadeInStart || progress >= animation.fadeOutEnd {
		return BubbleRenderState(opacity: 0, translateY: exitTranslate, scale: exitScale)
	}

	if progress < animation.visibleStart {
		let local = (progress - animation.fadeInStart) / max(animation.visibleStart - animation.fadeInStart, 0.0001)
		return BubbleRenderState(
			opacity: local,
			translateY: entryTranslate * (1 - local),
			scale: entryScale + ((1 - entryScale) * local)
		)
	}

	if progress <= animation.holdEnd {
		return BubbleRenderState(opacity: 1, translateY: 0, scale: 1)
	}

	let local = (progress - animation.holdEnd) / max(animation.fadeOutEnd - animation.holdEnd, 0.0001)
	return BubbleRenderState(
		opacity: 1 - local,
		translateY: exitTranslate * local,
		scale: 1 + ((exitScale - 1) * local)
	)
}

func dotOpacity(at seconds: Double, phaseOffset: Double) -> Double {
	let cycle = 1.0
	let progress = ((seconds + phaseOffset).truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle) / cycle
	if progress < 0.4 {
		return 0.25 + ((1.0 - 0.25) * (progress / 0.4))
	}

	if progress < 0.8 {
		let local = (progress - 0.4) / 0.4
		return 1.0 - ((1.0 - 0.25) * local)
	}

	return 0.25
}

func nsColor(from hex: String) throws -> NSColor {
	let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
	let sanitized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
	let expanded: String

	switch sanitized.count {
	case 3:
		expanded = sanitized.map { "\($0)\($0)" }.joined()
	case 6, 8:
		expanded = sanitized
	default:
		throw CLIError.invalidConfig("Unsupported color value \(hex). Use #RGB, #RRGGBB, or #RRGGBBAA.")
	}

	guard let raw = UInt64(expanded, radix: 16) else {
		throw CLIError.invalidConfig("Invalid hex color \(hex).")
	}

	if expanded.count == 6 {
		let red = CGFloat((raw & 0xFF0000) >> 16) / 255.0
		let green = CGFloat((raw & 0x00FF00) >> 8) / 255.0
		let blue = CGFloat(raw & 0x0000FF) / 255.0
		return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
	}

	let red = CGFloat((raw & 0xFF000000) >> 24) / 255.0
	let green = CGFloat((raw & 0x00FF0000) >> 16) / 255.0
	let blue = CGFloat((raw & 0x0000FF00) >> 8) / 255.0
	let alpha = CGFloat(raw & 0x000000FF) / 255.0
	return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

struct ChatRenderer {
	private let config: ResolvedChatConfig
	private let bubbleFont: NSFont
	private let statusFont: NSFont
	private let lineHeight: Double
	private let fontAscender: Double
	private let minBubbleHeight = 50.0
	private let bubbleCornerRadius = 25.0
	private let leftHorizontalPadding = 26.0
	private let rightHorizontalPadding = 24.0
	private let verticalPadding = 12.0
	private let statusGap = 19.0
	private let typingWidth = 92.0
	private let typingHeight = 42.0

	init(config: ResolvedChatConfig) {
		self.config = config
		self.bubbleFont = NSFont.systemFont(ofSize: CGFloat(config.fontSize), weight: .medium)
		self.statusFont = NSFont.systemFont(ofSize: 14, weight: .medium)
		self.lineHeight = ceil(config.fontSize * 1.18)
		self.fontAscender = ceil(Double(bubbleFont.ascender))
	}

	func makeLayout() -> ChatLayout {
		let maxBubbleWidth = config.canvasWidth * config.maxBubbleWidthRatio
		var yCursor = config.topInset
		var bubbleLayouts: [BubbleLayout] = []

		if config.typingEnabled {
			yCursor += typingHeight + config.bubbleGap
		}

		for (index, message) in config.messages.enumerated() {
			let padding = message.side == .left ? leftHorizontalPadding : rightHorizontalPadding
			let availableTextWidth = maxBubbleWidth - (padding * 2)
			let lines = wrapText(message.text, maxWidth: availableTextWidth, font: bubbleFont)
			let widestLine = lines.map { textWidth($0, font: bubbleFont) }.max() ?? 0
			let bubbleWidth = min(maxBubbleWidth, widestLine + (padding * 2))
			let bubbleHeight = max(minBubbleHeight, (Double(lines.count) * lineHeight) + (verticalPadding * 2))
			let bubbleX = message.side == .left ? config.sideInset : config.canvasWidth - config.sideInset - bubbleWidth
			let textTopInset = (bubbleHeight - (Double(lines.count) * lineHeight)) / 2
			let statusWidth = message.status.map { textWidth($0, font: statusFont) } ?? 0
			let animation = makeBubbleAnimation(for: index, totalMessages: config.messages.count)
			let statusAnimation = message.status == nil ? nil : makeStatusAnimation(for: animation)

			bubbleLayouts.append(
				BubbleLayout(
					id: index + 1,
					side: message.side,
					lines: lines,
					x: bubbleX,
					y: yCursor,
					width: bubbleWidth,
					height: bubbleHeight,
					textLeadingInset: padding,
					textTopInset: textTopInset,
					fillColor: message.bubbleColor,
					textColor: message.textColor,
					status: message.status,
					statusWidth: statusWidth,
					animation: animation,
					statusAnimation: statusAnimation
				)
			)

			yCursor += bubbleHeight
			if message.status != nil {
				yCursor += statusGap
			}
			yCursor += config.bubbleGap
		}

		let contentHeight = yCursor - config.bubbleGap + config.bottomInset
		let canvasHeight = max(config.requestedCanvasHeight ?? 0, contentHeight)
		let typingLayout = makeTypingLayout(firstBubbleY: bubbleLayouts.first?.y ?? config.topInset)

		return ChatLayout(
			canvasWidth: config.canvasWidth,
			canvasHeight: canvasHeight,
			lineHeight: lineHeight,
			fontAscender: fontAscender,
			messages: bubbleLayouts,
			typingIndicator: typingLayout
		)
	}

	func renderSVG(layout: ChatLayout) -> String {
		let bubbleKeyframes = layout.messages.map { bubble in
			bubbleAnimationKeyframes(name: "bubble-\(bubble.id)-cycle", animation: bubble.animation)
		}.joined(separator: "\n\n")

		let statusKeyframes = layout.messages.compactMap { bubble -> String? in
			guard let animation = bubble.statusAnimation else {
				return nil
			}
			return statusAnimationKeyframes(name: "status-\(bubble.id)-cycle", animation: animation)
		}.joined(separator: "\n\n")

		let typingKeyframes = layout.typingIndicator.map {
			bubbleAnimationKeyframes(name: "typing-cycle", animation: $0.animation)
		} ?? ""

		let bubbleGroups = layout.messages.map(renderBubbleGroup).joined(separator: "\n\n")
		let typingGroup = layout.typingIndicator.map(renderTypingGroup) ?? ""

		let background = config.theme.backgroundColor.map {
			"""
			  <rect x="0" y="0" width="\(Int(layout.canvasWidth.rounded()))" height="\(Int(layout.canvasHeight.rounded()))" fill="\($0)"/>
			"""
		} ?? ""

		return """
		<svg width="\(Int(layout.canvasWidth.rounded()))" height="\(Int(layout.canvasHeight.rounded()))" viewBox="0 0 \(Int(layout.canvasWidth.rounded())) \(Int(layout.canvasHeight.rounded()))" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="title desc">
		  <title id="title">\(xmlEscaped(config.title))</title>
		  <desc id="desc">\(xmlEscaped(config.description))</desc>
		  <style>
		    text {
		      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
		      font-size: \(Int(config.fontSize.rounded()))px;
		      font-weight: 500;
		    }

		    .status {
		      fill: \(config.theme.statusColor);
		      font-size: 14px;
		      font-weight: 500;
		    }

		    .typing,
		    .bubble,
		    .status-mark {
		      opacity: 0;
		      transform-box: fill-box;
		      transform-origin: center bottom;
		    }

		    #typing {
		      animation: typing-cycle \(String(format: "%.2f", config.animationSeconds))s infinite;
		    }

		    #typing-dot-1 {
		      animation: dot-blink 1s infinite 0.10s;
		    }

		    #typing-dot-2 {
		      animation: dot-blink 1s infinite 0.28s;
		    }

		    #typing-dot-3 {
		      animation: dot-blink 1s infinite 0.46s;
		    }

		\(layout.messages.map { """
		    #bubble-\($0.id) {
		      animation: bubble-\($0.id)-cycle \(String(format: "%.2f", config.animationSeconds))s infinite;
		    }
		""" }.joined(separator: "\n\n"))

		\(layout.messages.compactMap { bubble -> String? in
			guard bubble.statusAnimation != nil else { return nil }
			return """
		    #status-\(bubble.id) {
		      animation: status-\(bubble.id)-cycle \(String(format: "%.2f", config.animationSeconds))s infinite;
		    }
		"""
		}.joined(separator: "\n\n"))

		\(typingKeyframes)

		\(bubbleKeyframes)

		\(statusKeyframes)

		    @keyframes dot-blink {
		      0%, 80%, 100% {
		        opacity: 0.25;
		      }

		      40% {
		        opacity: 1;
		      }
		    }
		  </style>

		  <defs>
		    <symbol id="curl-right" viewBox="0 0 17 21">
		      <path d="M16.8869 20.1846C11.6869 20.9846 6.55352 18.1212 4.88685 16.2879C6.60472 12.1914 -4.00107 2.24186 2.99893 2.24148C4.61754 2.24148 6 -1.9986 11.8869 1.1846C11.9081 2.47144 11.8869 6.92582 11.8869 7.6842C11.8869 18.1842 17.8869 19.5813 16.8869 20.1846Z"/>
		    </symbol>
		    <symbol id="curl-left" viewBox="0 0 17 21">
		      <path d="M0.11315 20.1846C5.31315 20.9846 10.4465 18.1212 12.1132 16.2879C10.3953 12.1914 21.0011 2.24186 14.0011 2.24148C12.3825 2.24148 11 -1.9986 5.11315 1.1846C5.09194 2.47144 5.11315 6.92582 5.11315 7.6842C5.11315 18.1842 -0.88685 19.5813 0.11315 20.1846Z"/>
		    </symbol>
		  </defs>

		\(background)

		\(typingGroup)

		\(bubbleGroups)
		</svg>
		"""
	}

	func renderGIF(layout: ChatLayout, to url: URL) throws {
		let scale = config.gif.scale
		let width = Int((layout.canvasWidth * scale).rounded())
		let height = Int((layout.canvasHeight * scale).rounded())
		let frameCount = max(1, Int((config.animationSeconds * Double(config.gif.fps)).rounded()))
		let delayTime = config.animationSeconds / Double(frameCount)

		guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
			throw CLIError.renderFailed("Failed to create GIF destination at \(url.path).")
		}

		let gifProperties: [CFString: Any] = [
			kCGImagePropertyGIFDictionary: [
				kCGImagePropertyGIFLoopCount: config.gif.loopCount
			]
		]
		CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

		for frameIndex in 0..<frameCount {
			let progress = Double(frameIndex) / Double(frameCount)
			let seconds = progress * config.animationSeconds
			guard let bitmap = NSBitmapImageRep(
				bitmapDataPlanes: nil,
				pixelsWide: width,
				pixelsHigh: height,
				bitsPerSample: 8,
				samplesPerPixel: 4,
				hasAlpha: true,
				isPlanar: false,
				colorSpaceName: .deviceRGB,
				bitmapFormat: [],
				bytesPerRow: 0,
				bitsPerPixel: 0
			) else {
				throw CLIError.renderFailed("Failed to create a bitmap for GIF rendering.")
			}

			guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
				throw CLIError.renderFailed("Failed to create a graphics context for GIF rendering.")
			}

			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = graphicsContext
			defer { NSGraphicsContext.restoreGraphicsState() }

			let context = graphicsContext.cgContext
			graphicsContext.shouldAntialias = true
			context.interpolationQuality = .high
			context.translateBy(x: 0, y: CGFloat(height))
			context.scaleBy(x: 1, y: -1)

			NSColor.clear.setFill()
			NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

			if let backgroundColor = config.theme.backgroundColor {
				try nsColor(from: backgroundColor).setFill()
				NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
			}

			if let typing = layout.typingIndicator {
				let state = renderState(for: progress, animation: typing.animation)
				if state.opacity > 0.001 {
					try drawTypingIndicator(typing, state: state, at: seconds, scale: scale)
				}
			}

			for bubble in layout.messages {
				let state = renderState(for: progress, animation: bubble.animation)
				if state.opacity > 0.001 {
					try drawBubble(bubble, layout: layout, state: state, scale: scale)
				}

				if let statusAnimation = bubble.statusAnimation, bubble.status != nil {
					let statusState = renderState(for: progress, animation: statusAnimation, entryTranslate: 6, exitTranslate: 4, entryScale: 0.88, exitScale: 0.95)
					if statusState.opacity > 0.001 {
						try drawStatus(for: bubble, state: statusState, scale: scale)
					}
				}
			}

			guard let frameImage = bitmap.cgImage else {
				throw CLIError.renderFailed("Failed to extract a rendered GIF frame.")
			}

			let frameProperties: [CFString: Any] = [
				kCGImagePropertyGIFDictionary: [
					kCGImagePropertyGIFDelayTime: delayTime
				]
			]
			CGImageDestinationAddImage(destination, frameImage, frameProperties as CFDictionary)
		}

		guard CGImageDestinationFinalize(destination) else {
			throw CLIError.renderFailed("Failed to finalize GIF at \(url.path).")
		}
	}

	private func makeBubbleAnimation(for index: Int, totalMessages: Int) -> BubbleAnimation {
		let firstStart = config.typingEnabled ? 0.22 : 0.10
		let lastStart = min(0.68, firstStart + 0.46)
		let start: Double
		if totalMessages <= 1 {
			start = firstStart
		} else {
			let step = (lastStart - firstStart) / Double(totalMessages - 1)
			start = firstStart + (Double(index) * step)
		}

		return BubbleAnimation(
			fadeInStart: max(0, start - 0.06),
			visibleStart: start,
			holdEnd: 0.92,
			fadeOutEnd: 1.0
		)
	}

	private func makeStatusAnimation(for bubbleAnimation: BubbleAnimation) -> BubbleAnimation {
		let statusStart = min(bubbleAnimation.visibleStart + 0.10, 0.84)
		return BubbleAnimation(
			fadeInStart: max(statusStart - 0.06, bubbleAnimation.visibleStart + 0.02),
			visibleStart: statusStart,
			holdEnd: 0.92,
			fadeOutEnd: 1.0
		)
	}

	private func makeTypingLayout(firstBubbleY: Double) -> TypingIndicatorLayout? {
		guard config.typingEnabled else {
			return nil
		}

		let typingX = config.typingSide == .left ? config.sideInset : config.canvasWidth - config.sideInset - typingWidth
		let holdEnd = max(0.12, makeBubbleAnimation(for: 0, totalMessages: config.messages.count).visibleStart - 0.04)
		let animation = BubbleAnimation(
			fadeInStart: 0.04,
			visibleStart: 0.08,
			holdEnd: holdEnd,
			fadeOutEnd: min(holdEnd + 0.06, 0.28)
		)

		return TypingIndicatorLayout(
			side: config.typingSide,
			x: typingX,
			y: max(config.topInset, firstBubbleY - config.bubbleGap - typingHeight),
			width: typingWidth,
			height: typingHeight,
			bubbleColor: config.typingSide == .left ? config.theme.incomingBubbleColor : config.theme.outgoingBubbleColor,
			dotColor: config.theme.statusColor,
			animation: animation
		)
	}

	private func renderTypingGroup(_ typing: TypingIndicatorLayout) -> String {
		let tailHref = typing.side == .left ? "#curl-left" : "#curl-right"
		let tailX = typing.side == .left ? -4.0 : typing.width - 12.0

		return """
		  <g transform="translate(\(format(typing.x)) \(format(typing.y)))">
		    <g id="typing" class="typing">
		      <rect x="0" y="0" width="\(format(typing.width))" height="\(format(typing.height))" rx="21" fill="\(typing.bubbleColor)"/>
		      <use href="\(tailHref)" x="\(format(tailX))" y="22" width="16" height="17" fill="\(typing.bubbleColor)"/>
		      <circle id="typing-dot-1" cx="29" cy="21" r="4.5" fill="\(config.theme.statusColor)"/>
		      <circle id="typing-dot-2" cx="46" cy="21" r="4.5" fill="\(config.theme.statusColor)"/>
		      <circle id="typing-dot-3" cx="63" cy="21" r="4.5" fill="\(config.theme.statusColor)"/>
		    </g>
		  </g>
		"""
	}

	private func renderBubbleGroup(_ bubble: BubbleLayout) -> String {
		let tailHref = bubble.side == .left ? "#curl-left" : "#curl-right"
		let tailX = bubble.side == .left ? -3.0 : bubble.width - 16.0
		let textAnchor = bubble.side == .right ? "end" : "start"
		let textX = bubble.side == .right ? bubble.width - bubble.textLeadingInset : bubble.textLeadingInset
		let statusX = bubble.side == .right ? bubble.width : 0.0
		let statusAnchor = bubble.side == .right ? "end" : "start"

		let textContent = bubble.lines.enumerated().map { index, line in
			if index == 0 {
				return "<tspan x=\"\(format(textX))\" y=\"\(format(bubble.textTopInset + fontAscender))\">\(xmlEscaped(line))</tspan>"
			}
			return "<tspan x=\"\(format(textX))\" dy=\"\(format(lineHeight))\">\(xmlEscaped(line))</tspan>"
		}.joined(separator: "")

		let statusGroup: String
		if let status = bubble.status {
			statusGroup = """
		
		  <g transform="translate(\(format(bubble.x)) \(format(bubble.y)))">
		    <g id="status-\(bubble.id)" class="status-mark">
		      <text x="\(format(statusX))" y="\(format(bubble.height + statusGap))" text-anchor="\(statusAnchor)" class="status">\(xmlEscaped(status))</text>
		    </g>
		  </g>
		"""
		} else {
			statusGroup = ""
		}

		return """
		  <g transform="translate(\(format(bubble.x)) \(format(bubble.y)))">
		    <g id="bubble-\(bubble.id)" class="bubble">
		      <rect x="0" y="0" width="\(format(bubble.width))" height="\(format(bubble.height))" rx="\(format(bubbleCornerRadius))" fill="\(bubble.fillColor)"/>
		      <use href="\(tailHref)" x="\(format(tailX))" y="\(format(max(bubble.height - 20, 18)))" width="19" height="20" fill="\(bubble.fillColor)"/>
		      <text text-anchor="\(textAnchor)" class="" fill="\(bubble.textColor)">\(textContent)</text>
		    </g>
		  </g>\(statusGroup)
		"""
	}

	private func drawTypingIndicator(_ typing: TypingIndicatorLayout, state: BubbleRenderState, at seconds: Double, scale: Double) throws {
		guard let context = NSGraphicsContext.current?.cgContext else {
			return
		}

		let scaleFactor = CGFloat(scale)
		let pivotX = CGFloat((typing.x + (typing.width / 2)) * scale)
		let pivotY = CGFloat((typing.y + typing.height) * scale)
		context.saveGState()
		context.setAlpha(CGFloat(state.opacity))
		context.translateBy(x: 0, y: CGFloat(state.translateY) * scaleFactor)
		context.translateBy(x: pivotX, y: pivotY)
		context.scaleBy(x: CGFloat(state.scale), y: CGFloat(state.scale))
		context.translateBy(x: -pivotX, y: -pivotY)

		let fillColor = try nsColor(from: typing.bubbleColor)
		fillColor.setFill()
		NSBezierPath(roundedRect: NSRect(
			x: typing.x * scale,
			y: typing.y * scale,
			width: typing.width * scale,
			height: typing.height * scale
		), xRadius: 21 * scale, yRadius: 21 * scale).fill()

		try drawTail(side: typing.side, bubbleX: typing.x, bubbleY: typing.y, bubbleWidth: typing.width, bubbleHeight: typing.height, colorHex: typing.bubbleColor, scale: scale)

		let dotColor = try nsColor(from: typing.dotColor)
		let dotCenters = [29.0, 46.0, 63.0]
		let dotOffsets = [0.10, 0.28, 0.46]

		for (index, centerX) in dotCenters.enumerated() {
			dotColor.withAlphaComponent(dotOpacity(at: seconds, phaseOffset: dotOffsets[index])).setFill()
			NSBezierPath(ovalIn: NSRect(
				x: (typing.x + centerX - 4.5) * scale,
				y: (typing.y + 21 - 4.5) * scale,
				width: 9 * scale,
				height: 9 * scale
			)).fill()
		}

		context.restoreGState()
	}

	private func drawBubble(_ bubble: BubbleLayout, layout: ChatLayout, state: BubbleRenderState, scale: Double) throws {
		guard let context = NSGraphicsContext.current?.cgContext else {
			return
		}

		let scaleFactor = CGFloat(scale)
		let pivotX = CGFloat((bubble.x + (bubble.width / 2)) * scale)
		let pivotY = CGFloat((bubble.y + bubble.height) * scale)
		context.saveGState()
		context.setAlpha(CGFloat(state.opacity))
		context.translateBy(x: 0, y: CGFloat(state.translateY) * scaleFactor)
		context.translateBy(x: pivotX, y: pivotY)
		context.scaleBy(x: CGFloat(state.scale), y: CGFloat(state.scale))
		context.translateBy(x: -pivotX, y: -pivotY)

		let fillColor = try nsColor(from: bubble.fillColor)
		fillColor.setFill()
		NSBezierPath(roundedRect: NSRect(
			x: bubble.x * scale,
			y: bubble.y * scale,
			width: bubble.width * scale,
			height: bubble.height * scale
		), xRadius: bubbleCornerRadius * scale, yRadius: bubbleCornerRadius * scale).fill()

		try drawTail(side: bubble.side, bubbleX: bubble.x, bubbleY: bubble.y, bubbleWidth: bubble.width, bubbleHeight: bubble.height, colorHex: bubble.fillColor, scale: scale)

		let font = NSFont.systemFont(ofSize: CGFloat(config.fontSize * scale), weight: .medium)
		let textColor = try nsColor(from: bubble.textColor)
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: textColor
		]

		for (index, line) in bubble.lines.enumerated() {
			let lineRect = NSRect(
				x: (bubble.x + bubble.textLeadingInset) * scale,
				y: (bubble.y + bubble.textTopInset + (Double(index) * layout.lineHeight)) * scale,
				width: (bubble.width - (bubble.textLeadingInset * 2)) * scale,
				height: layout.lineHeight * scale
			)
			(line as NSString).draw(in: lineRect, withAttributes: attributes)
		}

		context.restoreGState()
	}

	private func drawStatus(for bubble: BubbleLayout, state: BubbleRenderState, scale: Double) throws {
		guard let status = bubble.status else {
			return
		}

		guard let context = NSGraphicsContext.current?.cgContext else {
			return
		}

		let scaleFactor = CGFloat(scale)
		let pivotX = CGFloat((bubble.x + (bubble.width / 2)) * scale)
		let pivotY = CGFloat((bubble.y + bubble.height + statusGap) * scale)
		context.saveGState()
		context.setAlpha(CGFloat(state.opacity))
		context.translateBy(x: 0, y: CGFloat(state.translateY) * scaleFactor)
		context.translateBy(x: pivotX, y: pivotY)
		context.scaleBy(x: CGFloat(state.scale), y: CGFloat(state.scale))
		context.translateBy(x: -pivotX, y: -pivotY)

		let font = NSFont.systemFont(ofSize: 14 * CGFloat(scale), weight: .medium)
		let color = try nsColor(from: config.theme.statusColor)
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: color
		]
		let originX = bubble.side == .right
			? (bubble.x + bubble.width - bubble.statusWidth) * scale
			: bubble.x * scale
		let rect = NSRect(
			x: originX,
			y: (bubble.y + bubble.height + 5) * scale,
			width: bubble.statusWidth * scale + 2,
			height: 18 * scale
		)
		(status as NSString).draw(in: rect, withAttributes: attributes)
		context.restoreGState()
	}

	private func drawTail(side: BubbleSide, bubbleX: Double, bubbleY: Double, bubbleWidth: Double, bubbleHeight: Double, colorHex: String, scale: Double) throws {
		let color = try nsColor(from: colorHex)
		color.setFill()

		let path = NSBezierPath()
		let scaleValue = scale
		let baseX = side == .left ? bubbleX : bubbleX + bubbleWidth
		let topY = bubbleY + max(bubbleHeight - 20, 18)
		let bottomY = bubbleY + bubbleHeight - 1

		if side == .left {
			path.move(to: NSPoint(x: (baseX + 13) * scaleValue, y: (topY + 1) * scaleValue))
			path.curve(
				to: NSPoint(x: (baseX - 2) * scaleValue, y: (bottomY - 3) * scaleValue),
				controlPoint1: NSPoint(x: (baseX + 5) * scaleValue, y: (topY + 6) * scaleValue),
				controlPoint2: NSPoint(x: (baseX - 1) * scaleValue, y: (bottomY - 7) * scaleValue)
			)
			path.curve(
				to: NSPoint(x: (baseX + 10) * scaleValue, y: bottomY * scaleValue),
				controlPoint1: NSPoint(x: (baseX + 1) * scaleValue, y: (bottomY + 2) * scaleValue),
				controlPoint2: NSPoint(x: (baseX + 6) * scaleValue, y: (bottomY + 1) * scaleValue)
			)
			path.curve(
				to: NSPoint(x: (baseX + 15) * scaleValue, y: (topY + 8) * scaleValue),
				controlPoint1: NSPoint(x: (baseX + 14) * scaleValue, y: (bottomY - 1) * scaleValue),
				controlPoint2: NSPoint(x: (baseX + 16) * scaleValue, y: (topY + 13) * scaleValue)
			)
		} else {
			path.move(to: NSPoint(x: (baseX - 13) * scaleValue, y: (topY + 1) * scaleValue))
			path.curve(
				to: NSPoint(x: (baseX + 2) * scaleValue, y: (bottomY - 3) * scaleValue),
				controlPoint1: NSPoint(x: (baseX - 5) * scaleValue, y: (topY + 6) * scaleValue),
				controlPoint2: NSPoint(x: (baseX + 1) * scaleValue, y: (bottomY - 7) * scaleValue)
			)
			path.curve(
				to: NSPoint(x: (baseX - 10) * scaleValue, y: bottomY * scaleValue),
				controlPoint1: NSPoint(x: (baseX - 1) * scaleValue, y: (bottomY + 2) * scaleValue),
				controlPoint2: NSPoint(x: (baseX - 6) * scaleValue, y: (bottomY + 1) * scaleValue)
			)
			path.curve(
				to: NSPoint(x: (baseX - 15) * scaleValue, y: (topY + 8) * scaleValue),
				controlPoint1: NSPoint(x: (baseX - 14) * scaleValue, y: (bottomY - 1) * scaleValue),
				controlPoint2: NSPoint(x: (baseX - 16) * scaleValue, y: (topY + 13) * scaleValue)
			)
		}

		path.close()
		path.fill()
	}

	private func format(_ number: Double) -> String {
		if number.rounded() == number {
			return String(Int(number))
		}
		return String(format: "%.2f", number)
	}
}

@main
struct readme_imess {
	static func main() {
		do {
			try run()
		} catch {
			fputs("error: \(error.localizedDescription)\n", stderr)
			exit(1)
		}
	}

	private static func run() throws {
		let arguments = Array(CommandLine.arguments.dropFirst())
		guard let command = arguments.first else {
			print(usage())
			return
		}

		switch command {
		case "generate":
			try generate(arguments: Array(arguments.dropFirst()))
		case "init":
			try writeStarterConfig(arguments: Array(arguments.dropFirst()))
		case "help", "--help", "-h":
			print(usage())
		default:
			throw CLIError.usage(usage())
		}
	}

	private static func generate(arguments: [String]) throws {
		guard let configPath = arguments.first else {
			throw CLIError.usage(usage())
		}

		var svgPath: String?
		var gifPath: String?
		var index = 1

		while index < arguments.count {
			switch arguments[index] {
			case "--svg":
				guard index + 1 < arguments.count else {
					throw CLIError.usage("Missing output path after --svg.\n\n\(usage())")
				}
				svgPath = arguments[index + 1]
				index += 2
			case "--gif":
				guard index + 1 < arguments.count else {
					throw CLIError.usage("Missing output path after --gif.\n\n\(usage())")
				}
				gifPath = arguments[index + 1]
				index += 2
			default:
				throw CLIError.usage("Unknown flag \(arguments[index]).\n\n\(usage())")
			}
		}

		let configURL = URL(fileURLWithPath: configPath)
		let defaultStem = configURL.deletingPathExtension().lastPathComponent
		let fallbackSVGPath = "output/\(defaultStem).svg"
		let resolvedSVGPath = svgPath ?? ((gifPath == nil) ? fallbackSVGPath : nil)

		let data = try Data(contentsOf: configURL)
		let decoder = JSONDecoder()
		let rawConfig = try decoder.decode(ChatConfig.self, from: data)
		let config = try rawConfig.resolved(fallbackName: defaultStem)
		let renderer = ChatRenderer(config: config)
		let layout = renderer.makeLayout()

		if let svgPath = resolvedSVGPath {
			let svgURL = URL(fileURLWithPath: svgPath)
			try createParentDirectory(for: svgURL)
			let svg = renderer.renderSVG(layout: layout)
			try svg.write(to: svgURL, atomically: true, encoding: .utf8)
			print("Wrote SVG to \(svgURL.path)")
		}

		if let gifPath = gifPath {
			let gifURL = URL(fileURLWithPath: gifPath)
			try createParentDirectory(for: gifURL)
			try renderer.renderGIF(layout: layout, to: gifURL)
			print("Wrote GIF to \(gifURL.path)")
		}
	}

	private static func writeStarterConfig(arguments: [String]) throws {
		let outputPath = arguments.first ?? "examples/starter-profile.json"
		let outputURL = URL(fileURLWithPath: outputPath)

		if FileManager.default.fileExists(atPath: outputURL.path) {
			throw CLIError.fileExists(outputURL.path)
		}

		let sample = ChatConfig(
			title: "Animated iMessage-style README conversation for Your Name",
			description: "A playful README intro that loops like an iMessage chat.",
			animationSeconds: 12,
			canvas: CanvasConfig(width: 960, height: nil, sideInset: 88, topInset: 34, bottomInset: 34, bubbleGap: 26, maxBubbleWidthRatio: 0.72, fontSize: 22),
			theme: ThemeConfig(incomingBubbleColor: "#E9E9EB", outgoingBubbleColor: "#509DF6", incomingTextColor: "#111111", outgoingTextColor: "#FFFFFF", statusColor: "#7D7D82", backgroundColor: nil),
			typingIndicator: TypingIndicatorConfig(enabled: true, side: .left),
			gif: GIFConfig(fps: 12, scale: 1.0, loopCount: 0),
			messages: [
				MessageConfig(side: .left, text: "Hi, I'm Your Name!", status: nil, bubbleColor: nil, textColor: nil),
				MessageConfig(side: .right, text: "Building warm, polished developer experiences.", status: "Delivered", bubbleColor: nil, textColor: nil),
				MessageConfig(side: .left, text: "Swap these messages, colors, and timing to match your own profile.", status: nil, bubbleColor: nil, textColor: nil)
			]
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		let data = try encoder.encode(sample)
		try createParentDirectory(for: outputURL)
		try (String(decoding: data, as: UTF8.self) + "\n").write(to: outputURL, atomically: true, encoding: .utf8)
		print("Wrote starter config to \(outputURL.path)")
	}

	private static func createParentDirectory(for url: URL) throws {
		let parent = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
	}

	private static func usage() -> String {
		"""
		readme-imess

		Commands:
		  swift run readme-imess init [config-path]
		  swift run readme-imess generate <config-path> [--svg <output.svg>] [--gif <output.gif>]

		Examples:
		  swift run readme-imess init examples/my-profile.json
		  swift run readme-imess generate examples/ktnguyenx.json
		  swift run readme-imess generate examples/ktnguyenx.json --svg ktnguyenx/assets/readme-chat.svg --gif ktnguyenx/assets/readme-chat.gif
		"""
	}
}
