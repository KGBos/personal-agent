//
//  ImageGenerationHandler.swift
//  PersonalAgent
//
//  Created by Leon Kuzmin on 1/7/26.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ImageGenerationHandler {
    var isPresented: Bool = false
    var prompt: String = ""
    
    /// Callback when an image is successfully generated and saved.
    var onImageSaved: ((URL) -> Void)?
    
    /// Callback when the sheet is dismissed without saving (optional).
    var onDismiss: (() -> Void)?

    /// Attempts to handle a tool call. Returns true if handled.
    func handle(toolCall: ToolCall) -> Bool {
        guard toolCall.name == "generate_image" else { return false }
        
        if let promptValue = toolCall.arguments["prompt"]?.value as? String {
            self.prompt = promptValue
            self.isPresented = true
            return true
        }
        
        return false
    }

    /// Handles the result from the Image Playground sheet.
    func handleResult(_ url: URL?) {
        isPresented = false
        if let url = url {
            onImageSaved?(url)
        } else {
            onDismiss?()
        }
    }
}
