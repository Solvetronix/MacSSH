import SwiftUI

#if canImport(MarkdownUI)
import MarkdownUI

struct GPTMarkdownView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#else

struct GPTMarkdownView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        AppleMarkdownView(text)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#endif


