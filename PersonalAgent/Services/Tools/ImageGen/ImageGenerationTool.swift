import Foundation

/// Tool for generating images using Apple Image Playground
/// Note: This tool triggers the Image Playground UI rather than generating directly
struct ImageGenerationTool: AgentTool {
    let name = "generate_image"
    let description = """
        Generate an image using Apple Image Playground. This will open the Image Playground interface \
        where the user can refine and generate the image. The user will see options for different styles \
        (animation, illustration, sketch) and can adjust the generated image.
        """
    let requiresConfirmation = true // User must approve opening Image Playground

    let parameterSchema = ToolParameterSchema(
        type: "object",
        description: nil,
        properties: [
            "prompt": .init(
                type: "string",
                description: "Description of the image to generate (e.g., 'a cat wearing a space helmet', 'sunset over mountains')",
                enumValues: nil,
                items: nil
            ),
            "style": .init(
                type: "string",
                description: "Preferred image style: 'animation', 'illustration', or 'sketch' (optional)",
                enumValues: ["animation", "illustration", "sketch"],
                items: nil
            )
        ],
        required: ["prompt"]
    )

    // Callback to trigger UI presentation
    var onImageGenerationRequested: ((ImageGenerationRequest) -> Void)?

    func execute(arguments: [String: Any]) async throws -> String {
        guard let prompt = arguments["prompt"] as? String else {
            throw ToolError.invalidArguments("Missing required 'prompt' parameter")
        }

        let style = arguments["style"] as? String

        // Create the request
        let request = ImageGenerationRequest(
            prompt: prompt,
            style: ImageGenerationStyle(rawValue: style ?? "") ?? .animation
        )

        // Trigger the UI on the main thread
        await MainActor.run {
            onImageGenerationRequested?(request)
        }

        return """
            Opening Image Playground with prompt: "\(prompt)"

            The Image Playground interface is now open. The user can:
            - View the generated image concept
            - Choose from different styles (Animation, Illustration, Sketch)
            - Refine the image before saving
            - Save the final image to the conversation

            Once the user saves or dismisses the Image Playground, the image (if saved) will appear in the chat.
            """
    }
}

// MARK: - Supporting Types

struct ImageGenerationRequest: Sendable {
    let prompt: String
    let style: ImageGenerationStyle
}

enum ImageGenerationStyle: String, Sendable {
    case animation
    case illustration
    case sketch

    var displayName: String {
        switch self {
        case .animation: return "Animation"
        case .illustration: return "Illustration"
        case .sketch: return "Sketch"
        }
    }
}
