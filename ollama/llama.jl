using VideoIO
using Images
using ImageIO
using FileIO
using HTTP
using JSON
using Base64

function capture_image(output_path="capture.jpg")
    println("Opening camera...")
    cam = VideoIO.opencamera()
    
    println("Camera opened, capturing frame...")
    img = read(cam)
    
    println("Frame captured, saving image...")
    save(output_path, img)
    
    close(cam)
    println("Image saved to: $output_path")
    return output_path
end

function analyze_image(image_path, question="What is in this image?")
    try
        # Read and encode image
        println("Reading image from: $image_path")
        base64_image = open(image_path, "r") do file
            base64encode(read(file))
        end
        
        # Prepare request
        body = Dict(
            "model" => "llava",
            "stream" => false,
            "messages" => [
                Dict(
                    "role" => "user",
                    "content" => question,
                    "images" => [base64_image]
                )
            ]
        )
        
        println("Sending request to Ollama...")
        
        # Make request
        response = HTTP.post(
            "http://localhost:11434/api/chat",
            ["Content-Type" => "application/json"],
            JSON.json(body)
        )
        
        # Parse response
        response_data = JSON.parse(String(response.body))
        
        # Extract the message content
        if haskey(response_data, "message") && 
           haskey(response_data["message"], "content")
            return response_data["message"]["content"]
        else
            return "Failed to get content from response"
        end
        
    catch e
        println("Error during analysis:")
        println(e)
        return "Error analyzing image: $(typeof(e))"
    end
end

function main()
    try
        # Capture image
        image_path = capture_image()
        
        # Analyze image
        println("\nAnalyzing image...")
        result = analyze_image(image_path)
        
        println("\nAnalysis Result:")
        println("---------------")
        println(result)
        println("---------------")
        
    catch e
        println("Error in main:")
        println(e)
    end
end

# Run the program
main()