using VideoIO
using Images
using ImageIO
using FileIO

function test_camera()
    println("Opening camera...")
    cam = VideoIO.opencamera()
    
    println("Camera opened, capturing frame...")
    img = read(cam)
    
    println("Frame captured, saving image...")
    save("test_capture.jpg", img)
    
    close(cam)
    println("Image saved to: test_capture.jpg")
    
    # Verify the image exists and has content
    if isfile("test_capture.jpg")
        filesize = stat("test_capture.jpg").size
        println("File size: $filesize bytes")
    else
        println("File was not created!")
    end
end

test_camera()
