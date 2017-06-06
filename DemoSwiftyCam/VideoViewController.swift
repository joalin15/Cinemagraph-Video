/*Copyright (c) 2016, Andrew Walz.
 
 Redistribution and use in source and binary forms, with or without modification,are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

import UIKit
import AVFoundation
import AVKit

class VideoViewController: UIViewController {
    
    @IBOutlet weak var maskDrawView: MaskDrawView!
    
    //MARK: - Properties
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var videoURL: URL?
    var player: AVPlayer?
    var playerController : AVPlayerViewController?
    var stillImage: UIImage?
    var maskImage: UIImage = UIImage(named: "mask2.png")!
    var backgroundView: UIImageView?
    var isAddingMask: Bool = false
    
//    init(videoURL: URL) {
//        self.videoURL = videoURL
//        super.init(nibName: nil, bundle: nil)
//    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var videoViewBounds: CGRect {
        let viewWidth = view.frame.width
        let viewHeight = view.frame.height
        let verticalPadding = (viewHeight - viewWidth)/2
        let videoViewBounds = CGRect(x: 0, y: verticalPadding, width: viewWidth, height: viewWidth)
        return videoViewBounds
    }
    
    //MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //overlapVideos(backgroundVideoURL: self.videoURL, foregroundVideoURL: self.videoURL) {
        self.squareCropVideo(inputURL: self.videoURL!) {
            (url) in
            guard let url = url else {
                return
            }
            self.videoURL = url
            
            self.player = AVPlayer(url: self.videoURL!)
            self.playerController = AVPlayerViewController()
            
            guard self.player != nil && self.playerController != nil else {
                return
            }
            self.player!.isMuted = true
            self.playerController!.showsPlaybackControls = false
            self.playerController!.player = self.player!
            self.playerController!.view.frame = self.videoViewBounds
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidReachEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player!.currentItem)
            
            self.stillImage = self.videoSnapshot(videoURL: self.videoURL!)
            
            self.backgroundView = UIImageView()
            self.backgroundView?.frame = self.videoViewBounds
            self.backgroundView?.image = self.stillImage
            
            self.addChildViewController(self.playerController!)
            self.view.addSubview(self.playerController!.view)
            self.view.addSubview(self.backgroundView!)

            self.player?.play()
            
//            let maskLayer = CALayer()
//            maskLayer.contents = self.maskImage.cgImage
//            maskLayer.frame = self.videoViewBounds
//            self.playerController?.view.layer.mask = maskLayer
        }

        
        let cancelButton = UIButton(frame: CGRect(x: 10.0, y: 10.0, width: 30.0, height: 30.0))
        cancelButton.setImage(#imageLiteral(resourceName: "cancel"), for: UIControlState())
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    // MARK: - IBActions
    
    @IBAction func addMask(_ sender: UIButton) {
        if (isAddingMask) {
            self.maskImage = maskDrawView.getImageFromDrawing()
            view.bringSubview(toFront: backgroundView!)
            view.sendSubview(toBack: maskDrawView)
            maskDrawView.isHidden = true
            isAddingMask = false
        } else {
            maskDrawView.isHidden = false
            view.bringSubview(toFront: maskDrawView)
            view.sendSubview(toBack: backgroundView!)
            isAddingMask = true
        }
    }
    
    @IBAction func applyMask(_ sender: UIButton) {
        let maskedImage = maskImage(image: stillImage!, mask: maskImage)
        backgroundView?.image = maskedImage
    }
    
    // MARK: - View Helper Functions
    
    func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc fileprivate func playerItemDidReachEnd(_ notification: Notification) {
        if self.player != nil {
            self.player!.seek(to: kCMTimeZero)
            self.player!.play()
        }
    }
    
    // MARK: - Video Cropping
    
    func squareCropVideo(inputURL: URL, completion: @escaping (URL?) -> ())
    {
        // Get input clip
        let videoAsset: AVAsset = AVAsset( url: inputURL )
        let clipVideoTrack = videoAsset.tracks( withMediaType: AVMediaTypeVideo ).first! as AVAssetTrack
        
        // Rotate to portrait
        let transformer = AVMutableVideoCompositionLayerInstruction( assetTrack: clipVideoTrack )
        let transform1 = CGAffineTransform( translationX: clipVideoTrack.naturalSize.height, y: -( clipVideoTrack.naturalSize.width - clipVideoTrack.naturalSize.height ) / 2 )
        let transform2 = transform1.rotated(by: CGFloat( M_PI_2 ) )
        transformer.setTransform( transform2, at: kCMTimeZero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(10, 60 ))
        
        instruction.layerInstructions = [transformer]
        
        // Make video to square
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize( width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.height )
        videoComposition.frameDuration = CMTimeMake( 1, 60)
        videoComposition.instructions = [instruction]
        
        // Export
        let croppedOutputFileUrl = self.getDestinationURL(fileName: "cropped")
        let exporter = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality)!
        exporter.videoComposition = videoComposition
        exporter.outputURL = croppedOutputFileUrl
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        
        exporter.exportAsynchronously( completionHandler: { () -> Void in
            switch (exporter.status) {
            case .completed:
                DispatchQueue.main.async(execute: {
                    completion( croppedOutputFileUrl )
                })
                print("Export Complete\n", exporter.status, exporter.error as Any);
                break;
            case .failed:
                print("Failed:\n",exporter.error as Any);
                DispatchQueue.main.async(execute: {
                    completion( nil )
                })
                break;
            default:
                break;
            }
        })
    }
    
    // MARK: - Masking/Overlaying Videos
    func overlapVideos (backgroundVideoURL: URL, foregroundVideoURL: URL, completion: @escaping (URL?) -> ()) {
        //First load your videos using AVURLAsset. Make sure you give the correct path of your videos.
        let backgroundVideo = AVURLAsset.init(url: backgroundVideoURL)
        let foregroundVideo = AVURLAsset.init(url: foregroundVideoURL)

        //Create AVMutableComposition Object which will hold our multiple AVMutableCompositionTrack or we can say it will hold our multiple videos.
        let mixComposition = AVMutableComposition.init()
        
        do {
            //Now we are creating the first AVMutableCompositionTrack containing our first video and add it to our AVMutableComposition object.
            let firstTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            //Now we set the length of the firstTrack equal to the length of the firstAsset and add the firstAsset to out newly created track at kCMTimeZero so video plays from the start of the track.
            try firstTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: backgroundVideo.duration), of: backgroundVideo.tracks(withMediaType: AVMediaTypeVideo).first!, at: kCMTimeZero)

            //Repeat the same process for the 2nd track as we did above for the first track.
            let secondTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            try secondTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: foregroundVideo.duration), of: foregroundVideo.tracks(withMediaType: AVMediaTypeVideo).first!, at: kCMTimeZero)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    
        //See how we are creating AVMutableVideoCompositionInstruction object. This object will contain the array of our AVMutableVideoCompositionLayerInstruction objects. You set the duration of the layer. You should add the length equal to the length of the longer asset in terms of duration.
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: backgroundVideo.duration)

        //We will be creating 2 AVMutableVideoCompositionLayerInstruction objects. Each for our 2 AVMutableCompositionTrack. Here we are creating AVMutableVideoCompositionLayerInstruction for out first track. See how we make use of Affinetransform to move and scale our First Track. So it is displayed at the bottom of the screen in smaller size.(First track in the one that remains on top).
        //Note: You have to apply transformation to scale and move according to your video size.
        let firstLayerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: backgroundVideo.tracks(withMediaType: AVMediaTypeVideo).first!)
        let scaleFirst = CGAffineTransform(scaleX: 0.6, y: 0.6)
        let moveFirst = CGAffineTransform(translationX: 320, y: 320)
        firstLayerInstruction.setTransform(scaleFirst.concatenating(moveFirst), at: kCMTimeZero)

        //Here we are creating AVMutableVideoCompositionLayerInstruction for our second track.see how we make use of Affinetransform to move and scale our second Track.
        let secondLayerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: foregroundVideo.tracks(withMediaType: AVMediaTypeVideo).first!)
        let scaleSecond = CGAffineTransform(scaleX: 0.9, y: 0.9)
        let moveSecond = CGAffineTransform(translationX: 0, y: 0)
        secondLayerInstruction.setTransform(scaleSecond.concatenating(moveSecond), at: kCMTimeZero)
        
        //Now we add our 2 created AVMutableVideoCompositionLayerInstruction objects to our AVMutableVideoCompositionInstruction in form of an array.
        mainInstruction.layerInstructions = [firstLayerInstruction, secondLayerInstruction]
        
        //Now we create AVMutableVideoComposition object.We can add multiple AVMutableVideoCompositionInstruction to this object.We have only one AVMutableVideoCompositionInstruction object in our example.You can use multiple AVMutableVideoCompositionInstruction objects to add multiple layers of effects such as fade and transition but make sure that time ranges of the AVMutableVideoCompositionInstruction objects dont overlap.
        let mainCompositionInst = AVMutableVideoComposition()
        mainCompositionInst.instructions = [mainInstruction]
        mainCompositionInst.frameDuration = CMTime(value: 1, timescale: 30)
        mainCompositionInst.renderSize = CGSize(width: 640, height: 640)
        
        let path = self.getDestinationURL(fileName: "overlapped")
        let url = NSURL(fileURLWithPath: path.absoluteString)

        let exporter = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        exporter.outputURL = url as URL
        exporter.videoComposition = mainCompositionInst
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        
        exporter.exportAsynchronously( completionHandler: { () -> Void in
            switch (exporter.status) {
            case .completed:
                DispatchQueue.main.async(execute: {
                    completion(URL(fileURLWithPath: path.absoluteString))
                })
                print("Export Complete\n", exporter.status, exporter.error as Any);
                break;
            case .failed:
                print("Failed:\n",exporter.error! as Any);
                DispatchQueue.main.async(execute: {
                    completion( nil )
                })
                break;
            default:
                break;
            }
        })
    }
    
    func videoSnapshot(videoURL: URL) -> UIImage? {
        
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.apertureMode = AVAssetImageGeneratorApertureModeProductionAperture
        
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let imageRef = try generator.copyCGImage(at: timestamp, actualTime: nil)
            
            let filterParameters = ["inputBrightness": sender.value]
            imageView.image = originalImage.af_imageWithAppliedCoreImageFilter("CIColorControls", filterParameters: filterParameters)
            return UIImage(cgImage: imageRef)
        }
        catch let error as NSError
        {
            print("Image generation failed with error \(error)")
            return nil
        }
    }
    
    // MARK: - Additional Helper Functions
    
    func getDestinationURL(fileName: String) -> URL {
        let paths =  NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)
        let path = paths[0] as NSString
        let url = "\(path)/\(fileName).mov"
        print(url)
        if (FileManager.default.fileExists(atPath: url)) {
            do {
                try FileManager.default.removeItem(atPath: url)
            }
            catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        
        return URL(fileURLWithPath: url)
    }
    
    func maskImage(image: UIImage, mask: UIImage) -> UIImage {
        
        guard let imageReference = image.cgImage,
            let maskReference = mask.cgImage else {
                return UIImage()
        }
        
        guard let imageMask = CGImage(maskWidth: maskReference.width,
                                      height: maskReference.height,
                                      bitsPerComponent: maskReference.bitsPerComponent,
                                      bitsPerPixel: maskReference.bitsPerPixel,                       bytesPerRow: maskReference.bytesPerRow,
                                      provider: maskReference.dataProvider!, decode: nil, shouldInterpolate: true) else {
                                        return UIImage()
        }
        
        let maskedReference = imageReference.masking(imageMask)
        
        let maskedImage = UIImage(cgImage:maskedReference!)
        
        return maskedImage
    }
}
