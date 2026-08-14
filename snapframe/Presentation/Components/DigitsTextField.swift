import AppKit
import SwiftUI

struct DigitsTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var allowsNegative: Bool = false
    var allowsTimecodeChars: Bool = false
    var allowsAllCharacters: Bool = false
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    var textColor: NSColor = .labelColor
    var alignment: NSTextAlignment = .center
    var onCommit: () -> Void = {}
    var onSubmit: () -> Void = {}
    var onFocusLeft: () -> Void = {}
    var focusGroup: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = SelectAllTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = textColor
        field.alignment = alignment
        field.delegate = context.coordinator
        field.stringValue = text
        field.onSelectAllOnFocus = true
        field.focusGroup = focusGroup
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.font = font
        nsView.textColor = textColor
        nsView.alignment = alignment
        (nsView as? SelectAllTextField)?.focusGroup = focusGroup
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DigitsTextField
        private var isCommitting = false

        init(_ parent: DigitsTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let filtered = DigitsTextField.filter(
                field.stringValue,
                allowsNegative: parent.allowsNegative,
                allowsTimecodeChars: parent.allowsTimecodeChars,
                allowsAllCharacters: parent.allowsAllCharacters
            )
            if filtered != field.stringValue {
                let editor = field.currentEditor()
                let selected = editor?.selectedRange ?? NSRange(location: filtered.count, length: 0)
                field.stringValue = filtered
                let loc = min(selected.location, filtered.count)
                editor?.selectedRange = NSRange(location: loc, length: 0)
            }
            parent.text = filtered
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            commit()
            parent.onFocusLeft()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                commit()
                parent.onSubmit()
                control.window?.makeFirstResponder(nil)
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                control.window?.makeFirstResponder(nil)
                parent.onSubmit()
                return true
            }
            return false
        }

        private func commit() {
            guard !isCommitting else { return }
            isCommitting = true
            defer { isCommitting = false }
            parent.onCommit()
        }
    }

    static func filter(
        _ raw: String,
        allowsNegative: Bool,
        allowsTimecodeChars: Bool,
        allowsAllCharacters: Bool = false
    ) -> String {
        if allowsAllCharacters { return raw }
        var result = ""
        for (i, ch) in raw.enumerated() {
            if ch.isNumber {
                result.append(ch)
            } else if allowsNegative, ch == "-", i == 0, !result.contains("-") {
                result.append(ch)
            } else if allowsTimecodeChars, Self.timecodeSeparatorChars.contains(ch) {
                result.append(ch)
            }
        }
        return result
    }

    private static let timecodeSeparatorChars = Set(":;.,/- ")

    static func hitView(_ view: NSView?, isInGroup group: String) -> Bool {
        var current = view
        while let node = current {
            if let field = node as? SelectAllTextField, field.focusGroup == group {
                return true
            }
            current = node.superview
        }
        return false
    }
}

private final class SelectAllTextField: NSTextField {
    var onSelectAllOnFocus = true
    var focusGroup: String?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, onSelectAllOnFocus {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentEditor() != nil else { return }
                self.currentEditor()?.selectAll(nil)
            }
        }
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if onSelectAllOnFocus {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentEditor() != nil else { return }
                self.currentEditor()?.selectAll(nil)
            }
        }
    }
}
