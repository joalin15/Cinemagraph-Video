//
//  MaskDrawView.swift
//  DemoSwiftyCam
//
//  Created by Joann Lin on 6/5/17.
//  Copyright © 2017 Cappsule. All rights reserved.
//

import Foundation
import UIKit

class MaskDrawView: UIView, UIAlertViewDelegate {
    
    var lastPoint: CGPoint = CGPoint.zero
    var points = [CGPoint]()
    var curves = [[CGPoint]]()
    var plusPath: UIBezierPath!
    
    var isSelectionFinished = false
    
    var callback: ((_ points: [CGPoint]) -> Void)?
    
    override func draw(_ rect: CGRect) {
        let path = drawPath(curve: points)
        path.stroke()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        points = [CGPoint]()
        
        if let touch = touches.first {
            lastPoint = touch.location(in: self)
            points.append(lastPoint)
        }
        print("touches began")
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let newPoint = touch.location(in: self)
            points.append(newPoint)
            
            lastPoint = newPoint
            setNeedsDisplay()
        }
    }
    
    func drawPath(curve: [CGPoint]) -> UIBezierPath {
        
        let path = UIBezierPath()
        
        UIColor.white.setStroke()
        //UIColor.clear.setFill()
        
        path.lineWidth = 20.0
        path.lineCapStyle = .round
        
        if curve.count > 0 {
            path.move(to: curve.first!)
            for point in curve {
                path.addLine(to: point)
            }
        }
        
        return path
    }
    
    func finishedDrawing() {
        let alert = UIAlertView.init(title: "Is it ok?", message: "", delegate: self, cancelButtonTitle: "Again", otherButtonTitles: "Ok")
        alert.show()
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        
        if alertView.cancelButtonIndex != buttonIndex {
            callback?(points)
        }
        //points = [CGPoint]()
        setNeedsDisplay()
    }
    
    func getImageFromDrawing() -> UIImage {
        UIGraphicsBeginImageContext(self.bounds.size);
        self.alpha = 1
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        self.alpha = 0.5
        return image
    }
}
