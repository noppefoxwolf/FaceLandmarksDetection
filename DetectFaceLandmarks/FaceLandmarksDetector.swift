//
//  FaceLandmarksDetector.swift
//  DetectFaceLandmarks
//
//  Created by mathieu on 09/07/2017.
//  Copyright © 2017 mathieu. All rights reserved.
//

import UIKit
import Vision

let previewImageView: UIImageView = .init()

class FaceLandmarksDetector {
  let sequenceRequestHandler = VNSequenceRequestHandler()
  
  open func processFaces2(for pixelBuffer: CVPixelBuffer, complete: @escaping (CIImage?) -> Void) {
    let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
    let request = VNDetectFaceLandmarksRequest { (request, error) in
      if error == nil {
        if let results = request.results as? [VNFaceObservation] {
          if let landmarks = results.first?.landmarks {
            //debugPrint(landmarks.nose?.pointsInImage(imageSize: inputImage.extent.size).first)
            //左上0,0でくる
            complete(self.process(inputImage: inputImage, faceLandmarks: landmarks))
          } else {
            complete(inputImage)
          }
        }
      } else {
        complete(inputImage)
        print(error!.localizedDescription)
      }
    }
    let vnImage = VNImageRequestHandler(ciImage: inputImage, options: [:])
    try? vnImage.perform([request])
  }
  
  open func processFaces(for pixelBuffer: CVPixelBuffer, complete: @escaping (CIImage?) -> Void) {
//    let pixelBuffer = pixelBuffer
//    let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
//      if error == nil {
//        if let results = request.results as? [VNFaceObservation] {
//          if let landmarks = results.first?.landmarks {
//            complete(self.process(image: pixelBuffer, faceLandmarks: landmarks)!)
//          } else {
//            complete(CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored))
//          }
//        }
//      } else {
//        complete(CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored))
//        print(error!.localizedDescription)
//      }
//    }
//    let vnImage = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//    try? vnImage.perform([detectFaceRequest])
  //    try? sequenceRequestHandler.perform([detectFaceRequest], on: cgImage)f
  }
  
  open func highlightFaces(for source: UIImage, complete: @escaping (UIImage) -> Void) {
    var resultImage = source
    let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
      if error == nil {
        if let results = request.results as? [VNFaceObservation] {
          for faceObservation in results {
            guard let landmarks = faceObservation.landmarks else {
              continue
            }
            let boundingRect = faceObservation.boundingBox
            
            resultImage = self.drawOnImage(source: resultImage, boundingRect: boundingRect, faceLandmarks: landmarks)
          }
        }
      } else {
        print(error!.localizedDescription)
      }
      complete(resultImage)
    }
    
    let cgImage = source.cgImage!
    let vnImage = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? vnImage.perform([detectFaceRequest])
//    try? sequenceRequestHandler.perform([detectFaceRequest], on: cgImage)
  }
  
  private func process(inputImage: CIImage, faceLandmarks: VNFaceLandmarks2D) -> CIImage? {
    if let noseCrest = faceLandmarks.noseCrest, let faceContour = faceLandmarks.faceContour {
      let size = inputImage.extent.size
      let midBottom = faceContour.pointsInImage(imageSize: size)[faceContour.pointCount / 2]
      let center = noseCrest.pointsInImage(imageSize: size).last!
      
      // 点P(x, y)を点A(a, b)の周りに角θだけ回転した点をQ(x”, y”)とすると
      // x' = (x - a) * cos(θ) - (y - b) * sin(θ) + a
      // y' = (x - a) * sin(θ) + (y - b) * cos(θ) + b
      func rotate(a: CGPoint, p: CGPoint, θ: CGFloat) -> CGPoint {
        return .init(
          x: (p.x - a.x) * cos(θ) - (p.y - a.y) * sin(θ) + a.x,
          y: (p.x - a.x) * sin(θ) + (p.y - a.y) * cos(θ) + a.y
        )
      }
      
      //https://manapedia.jp/text/636
      //点Ａ（ｘ1,ｙ1）と点Ｂ（ｘ2,ｙ2）をｍ：ｎに外分する点Ｑ（ｘ,ｙ）
      func externallyDivide(a: CGPoint, b: CGPoint, m: CGFloat, n: CGFloat) -> CGPoint {
        return .init(
          x: (-(n * a.x) + (m * b.x)) / (m - n),
          y: (-(n * a.y) + (m * b.y)) / (m - n)
        )
      }
      
      func getRadian(a: CGPoint, b: CGPoint) -> CGFloat {
        return atan2(b.y - a.y, b.x - a.x)
      }
      
      let extJow = externallyDivide(a: center, b: midBottom, m: 1, n: 0.5)
      
      let edgeA = rotate(a: center, p: extJow, θ: .pi / 2 * 1 - (.pi / 4)) //左下
      let edgeB = rotate(a: center, p: extJow, θ: .pi / 2 * 2 - (.pi / 4)) //左上
      let edgeC = rotate(a: center, p: extJow, θ: .pi / 2 * 3 - (.pi / 4)) //右上
      let edgeD = rotate(a: center, p: extJow, θ: .pi / 2 * 4 - (.pi / 4)) //右下
      
      // 抜き取り
      let correctionFilter = CIFilter(name: "CIPerspectiveCorrection")!
      correctionFilter.setValue(inputImage.clampedToExtent(), forKey: kCIInputImageKey) //ハミでてもちゃんとサイズ維持する
      correctionFilter.setValue(CIVector(x: edgeB.x, y: edgeB.y), forKey: "inputTopLeft")
      correctionFilter.setValue(CIVector(x: edgeA.x, y: edgeA.y), forKey: "inputTopRight")
      correctionFilter.setValue(CIVector(x: edgeD.x, y: edgeD.y), forKey: "inputBottomRight")
      correctionFilter.setValue(CIVector(x: edgeC.x, y: edgeC.y), forKey: "inputBottomLeft")
      
      // 処理
      let sepiaInputImage = correctionFilter.outputImage!
      let sepiaFilter = CIFilter(name: "CISepiaTone")!
      sepiaFilter.setValue(sepiaInputImage, forKey: kCIInputImageKey)
    
      //顔の傾き
      let faceRad = getRadian(a: center, b: midBottom)
    
      //右目
      let rightEyeFilter: CIFilter
      rightEye: do {
        let eyeDistortInput = sepiaFilter.outputImage!
        let cropedSize = eyeDistortInput.extent
        rightEyeFilter = CIFilter(name: "CIBumpDistortion")!
        rightEyeFilter.setValue(eyeDistortInput, forKey: kCIInputImageKey)
        if let pupil = faceLandmarks.rightPupil?.pointsInImage(imageSize: size).first {
          let rotatedPupil = rotate(a: center, p: pupil, θ: -faceRad) //顔の回転を加味する

          let p = CGPoint(x: rotatedPupil.x - center.x + cropedSize.width / 2,
                          y: rotatedPupil.y - center.y + cropedSize.height / 2)
          rightEyeFilter.setValue(CIVector(x: p.x, y: p.y), forKey: kCIInputCenterKey)
        }
        rightEyeFilter.setValue(50, forKey: kCIInputRadiusKey)
        rightEyeFilter.setValue(1.2, forKey: kCIInputScaleKey)
      }
      
      //左目
      let leftEyeFilter: CIFilter
      leftEye: do {
        let eyeDistortInput = rightEyeFilter.outputImage!
        let cropedSize = eyeDistortInput.extent
        leftEyeFilter = CIFilter(name: "CIBumpDistortion")!
        leftEyeFilter.setValue(eyeDistortInput, forKey: kCIInputImageKey)
        if let pupil = faceLandmarks.leftPupil?.pointsInImage(imageSize: size).first {
          let rotatedPupil = rotate(a: center, p: pupil, θ: -faceRad) //顔の回転を加味する

          let p = CGPoint(x: rotatedPupil.x - center.x + cropedSize.width / 2,
                          y: rotatedPupil.y - center.y + cropedSize.height / 2)
          leftEyeFilter.setValue(CIVector(x: p.x, y: p.y), forKey: kCIInputCenterKey)
        }
        leftEyeFilter.setValue(50, forKey: kCIInputRadiusKey)
        leftEyeFilter.setValue(1.2, forKey: kCIInputScaleKey)
      }
      
      // 合成
      let transformFilter = CIFilter(name: "CIPerspectiveTransform")!
      let transformInputImage = leftEyeFilter.outputImage!
      transformFilter.setValue(transformInputImage, forKey: kCIInputImageKey)
      transformFilter.setValue(CIVector(x: edgeB.x, y: edgeB.y), forKey: "inputTopLeft")
      transformFilter.setValue(CIVector(x: edgeA.x, y: edgeA.y), forKey: "inputTopRight")
      transformFilter.setValue(CIVector(x: edgeD.x, y: edgeD.y), forKey: "inputBottomRight")
      transformFilter.setValue(CIVector(x: edgeC.x, y: edgeC.y), forKey: "inputBottomLeft")
      
      let result = transformFilter.outputImage?.composited(over: inputImage)
      return result
    }
    return inputImage
  }
  
  private func drawOnImage(source: UIImage, boundingRect: CGRect, faceLandmarks: VNFaceLandmarks2D) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(source.size, false, 1)
    
    let context = UIGraphicsGetCurrentContext()!
    context.translateBy(x: 0.0, y: source.size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    //context.setBlendMode(CGBlendMode.colorBurn)
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    
    let rectWidth = source.size.width * boundingRect.size.width
    let rectHeight = source.size.height * boundingRect.size.height
    
    //draw image
    let rect = CGRect(x: 0, y:0, width: source.size.width, height: source.size.height)
    context.draw(source.cgImage!, in: rect)
    
    if let noseCrest = faceLandmarks.noseCrest, let faceContour = faceLandmarks.faceContour {
      let midBottom = faceContour.pointsInImage(imageSize: source.size)[faceContour.pointCount / 2]
      let center = noseCrest.pointsInImage(imageSize: source.size).last!
      
      // 点P(x, y)を点A(a, b)の周りに角θだけ回転した点をQ(x”, y”)とすると
      // x' = (x - a) * cos(θ) - (y - b) * sin(θ) + a
      // y' = (x - a) * sin(θ) + (y - b) * cos(θ) + b
      
      func rotate(a: CGPoint, p: CGPoint, θ: CGFloat) -> CGPoint {
        return .init(
          x: (p.x - a.x) * cos(θ) - (p.y - a.y) * sin(θ) + a.x,
          y: (p.x - a.x) * sin(θ) + (p.y - a.y) * cos(θ) + a.y
        )
      }
      
      func externallyDivide(a: CGPoint, b: CGPoint, m: CGFloat, n: CGFloat) -> CGPoint {
        return .init(
          x: (-(n * a.x) + (m * b.x)) / (m - n),
          y: (-(n * a.y) + (m * b.y)) / (m - n)
        )
      }
      let extJow = externallyDivide(a: center, b: midBottom, m: 1, n: 0.5)
      
      context.setStrokeColor(UIColor.white.cgColor)
      context.setLineWidth(2.0)
      context.addLines(between: [center, extJow])
      context.strokePath()
      
      let edgeA = rotate(a: center, p: extJow, θ: .pi / 2 * 1 - (.pi / 4))
      let edgeB = rotate(a: center, p: extJow, θ: .pi / 2 * 2 - (.pi / 4))
      let edgeC = rotate(a: center, p: extJow, θ: .pi / 2 * 3 - (.pi / 4))
      let edgeD = rotate(a: center, p: extJow, θ: .pi / 2 * 4 - (.pi / 4))
      
      context.setStrokeColor(UIColor.white.cgColor)
      context.setLineWidth(2.0)
      context.addLines(between: [edgeA, edgeB, edgeC, edgeD, edgeA])
      context.strokePath()
      
      let filter = CIFilter(name: "CIPerspectiveCorrection")!
      filter.setValue(CIImage(image: source), forKey: kCIInputImageKey)
      filter.setValue(CIVector(x: edgeB.x, y: edgeB.y), forKey: "inputTopLeft")
      filter.setValue(CIVector(x: edgeC.x, y: edgeC.y), forKey: "inputTopRight")
      filter.setValue(CIVector(x: edgeD.x, y: edgeD.y), forKey: "inputBottomRight")
      filter.setValue(CIVector(x: edgeA.x, y: edgeA.y), forKey: "inputBottomLeft")
      
      DispatchQueue.main.async {
        previewImageView.image = UIImage(ciImage: filter.outputImage!)
      }
      
//      //centerがmidBottomよりも右上にある前提
//      let p0: CGPoint = .zero
//      let p1: CGPoint = .init(x: center.x - midBottom.x, y: center.y - midBottom.y)
//      //http://www.geisya.or.jp/~mwm48961/kou2/linear_image3.html
//      let θ: CGFloat = .pi / 2.0 /* 90度 */
//      let p2: CGPoint /* p1をp0中心に90度移動させた点 */ = .init(
//        x: p1.x * cos(θ) - p1.y * sin(θ),
//        y: p1.x * sin(θ) + p1.y * cos(θ)
//      )
//      let edgeD: CGPoint = .init(x: p2.x + midBottom.x, y: p2.y + midBottom.y)
//      let r: CGFloat = sqrt(pow(p1.x, 2) + pow(p1.y, 2))
//
      
      
//      context.drawPath(using: CGPathDrawingMode.stroke)
    }
    
    
    //draw bound rect
    context.setStrokeColor(UIColor.green.cgColor)
    context.addRect(CGRect(x: boundingRect.origin.x * source.size.width, y:boundingRect.origin.y * source.size.height, width: rectWidth, height: rectHeight))
    context.drawPath(using: CGPathDrawingMode.stroke)
    
    //draw overlay
    context.setLineWidth(1.0)
    
    func drawFeature(_ feature: VNFaceLandmarkRegion2D, color: CGColor, close: Bool = false) {
      context.setStrokeColor(color)
      context.setFillColor(color)
      for point in feature.normalizedPoints {
        // Draw DEBUG numbers
        let textFontAttributes = [
          NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16),
          NSAttributedStringKey.foregroundColor: UIColor.white
        ]
        context.saveGState()
        // rotate to draw numbers
        context.translateBy(x: 0.0, y: source.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        let mp = CGPoint(x: boundingRect.origin.x * source.size.width + point.x * rectWidth, y: source.size.height - (boundingRect.origin.y * source.size.height + point.y * rectHeight))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: mp.x-2.0, y: mp.y-2), size: CGSize(width: 4.0, height: 4.0)))
        if let index = feature.normalizedPoints.index(of: point) {
          NSString(format: "%d", index).draw(at: mp, withAttributes: textFontAttributes)
        }
        context.restoreGState()
      }
      let mappedPoints = feature.normalizedPoints.map { CGPoint(x: boundingRect.origin.x * source.size.width + $0.x * rectWidth, y: boundingRect.origin.y * source.size.height + $0.y * rectHeight) }
      context.addLines(between: mappedPoints)
      if close, let first = mappedPoints.first, let lats = mappedPoints.last {
        context.addLines(between: [lats, first])
      }
      context.strokePath()
    }
    
    if let faceContour = faceLandmarks.faceContour {
      drawFeature(faceContour, color: UIColor.magenta.cgColor)
    }
    
    if let leftEye = faceLandmarks.leftEye {
      drawFeature(leftEye, color: UIColor.cyan.cgColor, close: true)
    }
    if let rightEye = faceLandmarks.rightEye {
      drawFeature(rightEye, color: UIColor.cyan.cgColor, close: true)
    }
    if let leftPupil = faceLandmarks.leftPupil {
      drawFeature(leftPupil, color: UIColor.cyan.cgColor, close: true)
    }
    if let rightPupil = faceLandmarks.rightPupil {
      drawFeature(rightPupil, color: UIColor.cyan.cgColor, close: true)
    }
    
    if let nose = faceLandmarks.nose {
      drawFeature(nose, color: UIColor.green.cgColor)
    }
    if let noseCrest = faceLandmarks.noseCrest {
      drawFeature(noseCrest, color: UIColor.green.cgColor)
    }
    
    if let medianLine = faceLandmarks.medianLine {
      drawFeature(medianLine, color: UIColor.gray.cgColor)
    }
    
    if let outerLips = faceLandmarks.outerLips {
      drawFeature(outerLips, color: UIColor.red.cgColor, close: true)
    }
    if let innerLips = faceLandmarks.innerLips {
      drawFeature(innerLips, color: UIColor.red.cgColor, close: true)
    }
    
    if let leftEyebrow = faceLandmarks.leftEyebrow {
      drawFeature(leftEyebrow, color: UIColor.blue.cgColor)
    }
    if let rightEyebrow = faceLandmarks.rightEyebrow {
      drawFeature(rightEyebrow, color: UIColor.blue.cgColor)
    }
    
    
    let coloredImg : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return coloredImg
  }
  
}


