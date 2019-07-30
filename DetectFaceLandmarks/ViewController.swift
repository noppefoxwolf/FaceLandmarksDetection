//
//  ViewController.swift
//  DetectFaceLandmarks
//
//  Created by mathieu on 21/06/2017.
//  Copyright © 2017 mathieu. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
  
  let faceDetector = FaceLandmarksDetector()
  let captureSession = AVCaptureSession()
  
  @IBOutlet weak var imageView: UIImageView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    imageView.contentMode = .scaleAspectFit
    // Do any additional setup after loading the view, typically from a nib.
    configureDevice()
    
    previewImageView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(previewImageView)
    NSLayoutConstraint.activate([
      previewImageView.topAnchor.constraint(equalTo: view.topAnchor),
      previewImageView.leftAnchor.constraint(equalTo: view.leftAnchor),
      previewImageView.widthAnchor.constraint(equalToConstant: 200),
      previewImageView.heightAnchor.constraint(equalToConstant: 200),
    ])
  }
  
  private func getDevice() -> AVCaptureDevice? {
    let discoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .front)
    return discoverSession.devices.first
  }
  
  private func configureDevice() {
    if let device = getDevice() {
      do {
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
          device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()
      } catch { print("failed to lock config") }
      
      do {
        let input = try AVCaptureDeviceInput(device: device)
        captureSession.addInput(input)
      } catch { print("failed to create AVCaptureDeviceInput") }
      
      captureSession.startRunning()
      
      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .utility))
      
      if captureSession.canAddOutput(videoOutput) {
        captureSession.addOutput(videoOutput)
      }
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  let ciContext = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)
  var isEnabled: Bool = true
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    isEnabled = false
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    isEnabled = true
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    let scale: CGFloat = 0.5
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    if !isEnabled {
      DispatchQueue.main.async {
        self.imageView.image = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored))
      }
      return
    }
    
    faceDetector.processFaces2(for: pixelBuffer, scale: scale) { (image) in
      DispatchQueue.main.async {
        guard let image = image else { return }
        self.imageView.image = UIImage(ciImage: image.cropped(to: .init(origin: .zero, size: .init(width: CGFloat(width) * scale, height: CGFloat(height) * scale))).oriented(.leftMirrored))
      }
    }
//    if let image = UIImage(sampleBuffer: sampleBuffer)?.flipped()?.imageWithAspectFit(size: maxSize) {
//      faceDetector.highlightFaces(for: image) { (resultImage) in
//        DispatchQueue.main.async {
//          self.imageView?.image = resultImage
//        }
//      }
//    }
  }
}


