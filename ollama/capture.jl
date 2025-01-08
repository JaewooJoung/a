using VideoIO
using Images
using ImageIO
using FileIO

function capture_image(output_path="capture.jpg")
    println("Opening camera...")
    cam = VideoIO.opencamera()
    
    println("Camera opened, capturing frame...")
    img = read(cam)
    
    println("Frame captured, saving image...")
    save(output_path, img)
    
    close(cam)
    println("Image saved to: $output_path")
    
    # Verify the image exists and has content
    if isfile(output_path)
        filesize = stat(output_path).size
        println("File size: $filesize bytes")
    else
        println("File was not created!")
    end
end

capture_image()