//
// Copyright (c) 2020 Ivan Sein <ivan@nextcloud.com>
//
// Author Ivan Sein <ivan@nextcloud.com>
//
// GNU GPL version 3 or any later version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
import UIKit
import SwiftUI
import Dynamic

struct EmojiTextFieldWrapper: UIViewRepresentable {
    @State var placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> EmojiTextField {
        let emojiTextField = EmojiTextField()
        emojiTextField.delegate = context.coordinator
        return emojiTextField
    }

    func updateUIView(_ uiView: EmojiTextField, context: Context) {
        uiView.text = text
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> EmojiTextFieldWrapper.Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextFieldWrapper

        init(parent: EmojiTextFieldWrapper) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if textField is EmojiTextField {
                if string.isSingleEmoji == false {
                    self.parent.text = ""
                } else {
                    self.parent.text = string
                }

                textField.endEditing(true)

                return false
            }

            return true
        }
    }
}

@objc class EmojiTextField: UITextField {

    override init(frame: CGRect) {
        super.init(frame: frame)

        tintColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        tintColor = .clear
    }

    // required for iOS 13
    override var textInputContextIdentifier: String? { "" } // return non-nil to show the Emoji keyboard ¯\_(ツ)_/¯

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes where mode.primaryLanguage == "emoji" {
            return mode
        }
        return nil
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()

        if result && NCUtils.isiOSAppOnMac() {
            // Open the emoji picker when running on Mac OS

            let app = Dynamic.NSApplication.sharedApplication()
            app.orderFrontCharacterPalette(nil)
        }

        return result
    }
}
