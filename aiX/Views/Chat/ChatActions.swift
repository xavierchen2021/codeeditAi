//
//  ChatActions.swift
//  aizen
//
//  Chat keyboard shortcut actions
//

import SwiftUI

struct ChatActions {
    let cycleModeForward: () -> Void
}

struct ChatActionsKey: FocusedValueKey {
    typealias Value = ChatActions
}

extension FocusedValues {
    var chatActions: ChatActions? {
        get { self[ChatActionsKey.self] }
        set { self[ChatActionsKey.self] = newValue }
    }
}
