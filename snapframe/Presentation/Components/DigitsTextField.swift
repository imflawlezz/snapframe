import AppKit
import SwiftUI

struct DigitsTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var allowsNegative: Bool = false
    var allowsTimecodeChars: Bool = false
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    var textColor: NSColor = .labelColor
    var alignment: NSTextAlignment = .center
    var onCommit: () -> Void = {}

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
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text, nsView.currentEditor() == nil {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.font = font
        nsView.textColor = textColor
        nsView.alignment = alignment
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DigitsTextField

        init(_ parent: DigitsTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let filtered = DigitsTextField.filter(
                field.stringValue,
                allowsNegative: parent.allowsNegative,
                allowsTimecodeChars: parent.allowsTimecodeChars
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
            parent.onCommit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                control.window?.makeFirstResponder(nil)
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }

    static func filter(_ raw: String, allowsNegative: Bool, allowsTimecodeChars: Bool) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            if ch.isNumber {
                result.append(ch)
            } else if allowsNegative, ch == "-", i == 0, !result.contains("-") {
                result.append(ch)
            } else if allowsTimecodeChars, ch == ":" || ch == "." {
                result.append(ch)
            }
        }
        return result
    }
}

private final class SelectAllTextField: NSTextField {
    var onSelectAllOnFocus = true

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, onSelectAllOnFocus {
            DispatchQueue.main.async { [weak self] in
                self?.currentEditor()?.selectAll(nil)
            }
        }
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if onSelectAllOnFocus, let editor = currentEditor() {
            DispatchQueue.main.async {
                editor.selectAll(nil)
            }
        }
    }
}
