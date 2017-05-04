//
//  AppDelegate.swift
//  BlurVideoDetector
//
//  Created by Alex on 4/30/17.
//  Copyright © 2017 alex. All rights reserved.

//
import UIKit
import MetalKit
import MetalPerformanceShaders
import Accelerate
import AVFoundation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    fileprivate var device: MTLDevice!
    fileprivate var commandQueue: MTLCommandQueue!

    fileprivate var textureLoader: MTKTextureLoader!
    fileprivate var ciContext: CIContext!
    fileprivate var sourceTexture: MTLTexture? = nil

    fileprivate var videoCapture: VideoCapture!

    @IBOutlet fileprivate weak var predictLabel: UILabel!
    var previewView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load default device.
        device = MTLCreateSystemDefaultDevice()

        // Make sure the current device supports MetalPerformanceShaders.
        guard MPSSupportsMTLDevice(device) else {
            showAlert(title: "Not Supported", message: "MetalPerformanceShaders is not supported on current device", handler: { (action) in
                self.navigationController!.popViewController(animated: true)
            })
            return
        }
        
        let spec = VideoSpec(fps: 30, size: CGSize(width: 640, height: 480))
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: nil)
        videoCapture.imageBufferHandler = { [unowned self] (imageBuffer, timestamp, outputBuffer) in
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

            // get a texture from this CGImage
            do {
                self.sourceTexture = try self.textureLoader.newTexture(with: cgImage, options: [:])
                self.setUpMetalView()
            }
            catch let error as NSError {
                fatalError("Unexpected error ocurred: \(error.localizedDescription).")
            }
            // run inference neural network to get predictions and display them
        }

        // Load any resources required for rendering.

        // Create new command queue.
        commandQueue = device!.makeCommandQueue()

        // make a textureLoader to get our input images as MTLTextures
        textureLoader = MTKTextureLoader(device: device!)

        // Load the appropriate Network
        //   inception3Net = Inception3Net(withCommandQueue: commandQueue)

        // we use this CIContext as one of the steps to get a MTLTexture
        ciContext = CIContext.init(mtlDevice: device)
    }

    func setUpMetalView() {
        let size = view.frame.size
      //  previewView = MTKView(frame: CGRect(origin: CGPoint.zero, size: size))
        previewView = MTKView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 300, height: 300)))
        previewView.center = view.center
        previewView.layer.borderColor = UIColor.white.cgColor
        previewView.layer.borderWidth = 5
        previewView.layer.cornerRadius = 20
        previewView.clipsToBounds = true

        view.addSubview(previewView)
        previewView.device = MTLCreateSystemDefaultDevice()
        previewView.delegate = self
        previewView.depthStencilPixelFormat = .depth32Float_stencil8
        previewView.colorPixelFormat = .bgra8Unorm
        previewView.framebufferOnly = false
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else { return }
        videoCapture.startCapture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else { return }
        videoCapture.resizePreview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else { return }
        videoCapture.stopCapture()

        navigationController?.setNavigationBarHidden(false, animated: true)
        super.viewWillDisappear(animated)
    }

}


extension  ViewController:MTKViewDelegate  {
    func draw(in view: MTKView)  {
        // encoding command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let laplacianblur = MPSImageLaplacian(device: previewView.device!)
        laplacianblur.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture!, destinationTexture: previewView.currentDrawable!.texture)
        
        
        // 運行MetalPerformanceShader高斯模糊
        laplacianblur.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture!, destinationTexture: previewView.currentDrawable!.texture)
        // 提交`commandBuffer`
        commandBuffer.present(previewView.currentDrawable!)
        
        // commit the commandBuffer and wait for completion on CPU
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        DispatchQueue.main.async {
            self.predictLabel.text = "hi"
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }

}

