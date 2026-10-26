import SwiftUI

/// As licenças do código aberto de que o ExcaliburForms é feito, por inteiro,
/// para que os avisos acompanhem o app (como as licenças exigem).
struct OpenSourceLicensesView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let license: String
        let text: String
    }

    private static let mit = """
    Permission is hereby granted, free of charge, to any person obtaining a copy \
    of this software and associated documentation files (the "Software"), to deal \
    in the Software without restriction, including without limitation the rights \
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
    copies of the Software, and to permit persons to whom the Software is \
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all \
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
    SOFTWARE.
    """

    private static let ofl = """
    This Font Software is licensed under the SIL Open Font License, Version 1.1. \
    The fonts may be used, studied, modified and redistributed freely, as long as \
    they are not sold by themselves. The fonts, including any derivative works, \
    can be bundled, embedded, redistributed and/or sold with any software provided \
    that any reserved names are not used by derivative works. The fonts and \
    derivatives, however, cannot be released under any other type of license.

    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

    Full license text: https://openfontlicense.org
    """

    private let entries: [Entry] = [
        Entry(
            id: "excaliburforms",
            name: "ExcaliburForms",
            license: "Código-fonte aberto",
            text: """
            Copyright (C) 2026 Matheus Faria
            Source code: https://github.com/matthfaria96/ExcaliburForms

            ExcaliburForms is a modified version of Excalidraw (upstream b7de45e). \
            The changes live in excalidraw/packages and excalidraw/excalibur-web.
            """
        ),
        Entry(
            id: "excalidraw",
            name: "Excalidraw",
            license: "MIT License",
            text: "Copyright (c) 2020 Excalidraw\nhttps://github.com/excalidraw/excalidraw\n\n" + mit
        ),
        Entry(
            id: "excalifont",
            name: "Excalifont e Virgil",
            license: "SIL Open Font License 1.1",
            text: "Copyright (c) 2024 Excalidraw\n\n" + ofl
        ),
        Entry(
            id: "xiaolai",
            name: "Xiaolai",
            license: "SIL Open Font License 1.1",
            text: "Copyright © 2020 LXGW\n\n" + ofl
        ),
        Entry(
            id: "nunito",
            name: "Nunito",
            license: "SIL Open Font License 1.1",
            text: "Copyright 2014 The Nunito Project Authors\n\n" + ofl
        ),
        Entry(
            id: "lilita",
            name: "Lilita One",
            license: "SIL Open Font License 1.1",
            text: "Copyright 2011 Juan Montoreano\n\n" + ofl
        ),
        Entry(
            id: "assistant",
            name: "Assistant",
            license: "SIL Open Font License 1.1",
            text: "Copyright 2010 The Assistant Project Authors\n\n" + ofl
        ),
        Entry(
            id: "cascadia",
            name: "Cascadia Code",
            license: "SIL Open Font License 1.1",
            text: "Copyright (c) 2019 Microsoft Corporation\n\n" + ofl
        ),
        Entry(
            id: "liberation",
            name: "Liberation Sans",
            license: "SIL Open Font License 1.1",
            text: "Copyright (c) 2012 Red Hat, Inc.\n\n" + ofl
        ),
        Entry(
            id: "comicshanns",
            name: "Comic Shanns",
            license: "MIT License",
            text: "Copyright (c) 2018 Shannon Miwa\n\n" + mit
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Licenças de código aberto")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("O ExcaliburForms é feito sobre os projetos abaixo. Os avisos de direitos autorais e as licenças ficam aqui, como essas licenças exigem.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.name).font(.headline)
                                Text(entry.license)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text(entry.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 540)
    }
}
