import AppKit
import SwiftUI

/// Multiline draft editor that keeps selection in sync for on-screen key insertion.
struct LocalDraftTextView: NSViewRepresentable {
  @Binding var draft: DraftTextBuffer
  let fontSize: CGFloat

  func makeCoordinator() -> Coordinator {
    Coordinator(draft: $draft)
  }

  func makeNSView(context: Context) -> LocalDraftFieldView {
    let view = LocalDraftFieldView()
    view.textView.delegate = context.coordinator
    context.coordinator.textView = view.textView
    context.coordinator.apply(draft, to: view.textView, registersUndo: false)
    view.apply(fontSize: fontSize)
    return view
  }

  func updateNSView(_ view: LocalDraftFieldView, context: Context) {
    context.coordinator.draft = $draft
    context.coordinator.apply(draft, to: view.textView)
    view.apply(fontSize: fontSize)
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var draft: Binding<DraftTextBuffer>
    weak var textView: NSTextView?
    private var isApplyingExternalChange = false

    init(draft: Binding<DraftTextBuffer>) {
      self.draft = draft
    }

    func apply(
      _ draft: DraftTextBuffer,
      to textView: NSTextView,
      registersUndo: Bool = true
    ) {
      isApplyingExternalChange = true
      defer { isApplyingExternalChange = false }

      let textChanged = textView.string != draft.text
      let selectionChanged = textView.selectedRange() != draft.selectedRange

      if textChanged {
        if registersUndo {
          textView.breakUndoCoalescing()
          registerUndo(of: currentDraft(in: textView), with: textView.undoManager)
        }
        textView.string = draft.text
      }
      if textView.selectedRange() != draft.selectedRange {
        textView.setSelectedRange(draft.selectedRange)
      }
      if textChanged || selectionChanged {
        textView.scrollRangeToVisible(draft.selectedRange)
      }
    }

    func textDidChange(_ notification: Notification) {
      guard !isApplyingExternalChange, let textView else { return }
      draft.wrappedValue = DraftTextBuffer(
        text: textView.string,
        selectedRange: textView.selectedRange()
      )
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard !isApplyingExternalChange, let textView else { return }
      var next = draft.wrappedValue
      next.selectedRange = textView.selectedRange()
      draft.wrappedValue = next
    }

    private func restore(_ restoredDraft: DraftTextBuffer) {
      guard let textView else { return }
      registerUndo(of: currentDraft(in: textView), with: textView.undoManager)
      apply(restoredDraft, to: textView, registersUndo: false)
      draft.wrappedValue = restoredDraft
    }

    private func registerUndo(of previousDraft: DraftTextBuffer, with undoManager: UndoManager?) {
      undoManager?.registerUndo(withTarget: self) { coordinator in
        coordinator.restore(previousDraft)
      }
    }

    private func currentDraft(in textView: NSTextView) -> DraftTextBuffer {
      DraftTextBuffer(
        text: textView.string,
        selectedRange: textView.selectedRange()
      )
    }
  }
}

/// Multiline editor styled like a native rounded text field.
final class LocalDraftFieldView: NSView {
  let textView: NSTextView
  private let scrollView: NSScrollView

  /// Matches modern rounded NSTextField corner radius at control size.
  private let cornerRadius: CGFloat = 6

  init() {
    scrollView = NSScrollView()
    textView = NSTextView()
    super.init(frame: .zero)

    wantsLayer = true
    focusRingType = .exterior

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.focusRingType = .none
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    textView.isRichText = false
    textView.allowsUndo = true
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.font = .systemFont(ofSize: NSFont.systemFontSize)
    textView.textContainerInset = NSSize(width: 5, height: 5)
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.focusRingType = .none
    textView.minSize = .zero
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: 0,
      height: CGFloat.greatestFiniteMagnitude
    )

    scrollView.documentView = textView
    addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  func apply(fontSize: CGFloat) {
    guard textView.font?.pointSize != fontSize else { return }
    textView.font = .systemFont(ofSize: fontSize)
  }

  override var wantsUpdateLayer: Bool { true }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func updateLayer() {
    guard let layer else { return }

    let usesDarkAppearance = effectiveAppearance.bestMatch(
      from: [.darkAqua, .aqua]
    ) == .darkAqua
    if usesDarkAppearance {
      layer.backgroundColor = NSColor(hex: "#19191A").cgColor
      layer.borderColor = NSColor(hex: "#353738").cgColor
    } else {
      layer.backgroundColor = NSColor(hex: "#F6F6F6").cgColor
      layer.borderColor = NSColor(hex: "#D6D6D6").cgColor
    }
    layer.borderWidth = 1
    layer.cornerRadius = cornerRadius
    layer.cornerCurve = .continuous
    layer.masksToBounds = true
  }

  override func layout() {
    super.layout()
    let width = max(scrollView.contentSize.width, 0)
    textView.textContainer?.containerSize = NSSize(
      width: width,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.frame.size.width = width
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override var acceptsFirstResponder: Bool { true }

  override func becomeFirstResponder() -> Bool {
    window?.makeFirstResponder(textView) ?? false
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(textView)
    textView.mouseDown(with: event)
  }

  override var focusRingMaskBounds: NSRect { bounds }

  override func drawFocusRingMask() {
    NSBezierPath(
      roundedRect: bounds,
      xRadius: cornerRadius,
      yRadius: cornerRadius
    ).fill()
  }
}
