//
//  ChatSessionViewModel+Attachments.swift
//  aizen
//
//  Attachment handling for chat sessions
//

import Foundation
import SwiftUI

extension ChatSessionViewModel {
    // MARK: - Attachment Management

    func removeAttachment(_ attachment: ChatAttachment) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            attachments.removeAll { $0 == attachment }
        }
    }

    func addFileAttachment(_ url: URL) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            attachments.append(.file(url))
        }
    }

    func addReviewCommentsAttachment(_ markdown: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            attachments.append(.reviewComments(markdown))
        }
    }
}
