//
//  VideoTransitions.swift
//  Transitions
//
//  Created by German Pereyra on 9/16/16.
//  Copyright © 2016 German Pereyra. All rights reserved.
//

import Foundation
import AVFoundation

class VideoTransitions {
    
    let cropSize = CGSizeMake(800, 800)
    let transDuration = CMTimeMake(2, 1)
    
    func buildCompositionTracks2(composition: AVMutableComposition,
                                transitionDuration: CMTime,
                                assetsWithVideoTracks: [AVAsset]) -> Void {
        let compositionTrackA = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let compositionTrackB = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let videoTracks = [compositionTrackA, compositionTrackB]
        
        var cursorTime = kCMTimeZero
        
        for (var i = 0 ; i < assetsWithVideoTracks.count ; ++i) {
            let trackIndex = i % 2
            let currentTrack = videoTracks[trackIndex]
            let assetTrack = assetsWithVideoTracks[i].tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack
            let timeRange = CMTimeRangeMake(kCMTimeZero, assetsWithVideoTracks[i].duration)
            do {
                try currentTrack.insertTimeRange( timeRange,
                                                  ofTrack: assetTrack,
                                                  atTime: cursorTime)
            } catch {}
            // Overlap clips by tranition duration // 4
            cursorTime = CMTimeAdd(cursorTime, assetsWithVideoTracks[i].duration)
            cursorTime = CMTimeSubtract(cursorTime, transitionDuration)
        }
        // Currently leaving out voice overs and movie tracks. // 5
    }
    
    
    func buildVideoCompositionAndInstructions2(
        composition: AVMutableComposition,
        assets: [AVAsset],
        renderSize: CGSize) -> AVMutableVideoComposition {
        
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        let tracks = composition.tracksWithMediaType(AVMediaTypeVideo)
        
        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOfAsset: composition)
        
        // Now create the instructions from the various time ranges.
        var index: Int = 0
        var cursorTime: CMTime = kCMTimeZero
        for asset in assets
        {
            let trackIndex = index % 2
            let currentTrack = tracks[trackIndex]
            
            print("\(asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize) \(currentTrack.naturalSize)")
            let notAnimatedInstruction = AVMutableVideoCompositionInstruction()
            let notAnimetedInstructionDuration = CMTimeSubtract(CMTimeSubtract(asset.duration, transDuration), transDuration)
            //let instructionDuration = CMTimeSubtract(asset.duration, transDuration)
            let instructionTimeRange = CMTimeRange(start: cursorTime, duration: notAnimetedInstructionDuration)
            let transitionStart = CMTimeAdd(cursorTime, notAnimetedInstructionDuration)
            let animatedInstructionTimeRange = CMTimeRange(start: transitionStart, duration: transDuration)
            
            
            notAnimatedInstruction.timeRange = instructionTimeRange
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: currentTrack)
            notAnimatedInstruction.layerInstructions = [layerInstruction]
            compositionInstructions.append(notAnimatedInstruction)
            setLayerInstructions(layerInstruction, timeStart: notAnimatedInstruction.timeRange.start, videoTrack: currentTrack, originalSize: asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize)
            
            
            let animatedInstruction = AVMutableVideoCompositionInstruction()
            animatedInstruction.timeRange = animatedInstructionTimeRange
            
            // Determine the foreground and background tracks.
            let fgTrack = tracks[trackIndex]
            let bgTrack = tracks[1 - trackIndex]
            
            // Create the "from layer" instruction.
            let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: fgTrack)
            
            // Make the opacity ramp and apply it to the from layer instruction.
            fLInstruction.setOpacityRampFromStartOpacity(1.0, toEndOpacity:0.0,
                                                         timeRange: animatedInstruction.timeRange)
            
            
            // Create the "to layer" instruction. Do I need this?
            let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: bgTrack)
            animatedInstruction.layerInstructions = [fLInstruction, tLInstruction]
            compositionInstructions.append(animatedInstruction)
            
            let transformResult = setLayerInstructions(fLInstruction, timeStart: animatedInstruction.timeRange.start, videoTrack: fgTrack, originalSize: asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize)
            setLayerInstructions(tLInstruction, timeStart: animatedInstruction.timeRange.start, videoTrack: bgTrack, originalSize: asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize)
            
            let animatedOutTransform = CGAffineTransformMakeTranslation(cropSize.width * 2, 0.0)
            fLInstruction.setTransformRampFromStartTransform(transformResult, toEndTransform: animatedOutTransform, timeRange: animatedInstruction.timeRange)
            
            
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            //cursorTime = CMTimeSubtract(cursorTime, transDuration)
            index+=1
        }
        
        videoComposition.instructions = compositionInstructions
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTimeMake(1, 30)
        //  videoComposition.renderScale = 1.0 // This is a iPhone only option.
        return videoComposition
    }
    
    
    func setLayerInstructions(instructionLayer: AVMutableVideoCompositionLayerInstruction, timeStart: CMTime, videoTrack: AVMutableCompositionTrack, originalSize: CGSize) -> CGAffineTransform {
        var scaleFactor: CGFloat = 0
        
        if originalSize.width < originalSize.height {
            scaleFactor = cropSize.width / originalSize.width
        } else {
            scaleFactor = cropSize.width / originalSize.height
        }
        
        let scaledSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        let topLeft = CGPoint(x: cropSize.width * 0.5 - scaledSize.width * 0.5, y: cropSize.width  * 0.5 - scaledSize.height * 0.5)
        
        var orientationTransform = videoTrack.preferredTransform
        
        /* fix the orientation transform */
        
        if orientationTransform.tx == originalSize.width || orientationTransform.tx == originalSize.height {
            orientationTransform.tx = cropSize.width
        }
        
        if orientationTransform.ty == originalSize.width || orientationTransform.ty == originalSize.height {
            orientationTransform.ty = cropSize.width
        }
        
        let transform = CGAffineTransformConcat(CGAffineTransformConcat(CGAffineTransformMakeScale(scaleFactor, scaleFactor), CGAffineTransformMakeTranslation(topLeft.x, topLeft.y)), orientationTransform)
        
        instructionLayer.setTransform(transform, atTime: timeStart)
        return transform
    }
    

    func makeExportSession(preset: String,
                           videoComposition: AVMutableVideoComposition,
                           composition: AVMutableComposition) -> AVAssetExportSession {
        let session = AVAssetExportSession(asset: composition, presetName: preset)
        session!.videoComposition = videoComposition.copy() as! AVVideoComposition
        // session.outputFileType = "com.apple.m4v-video"
        // session.outputFileType = AVFileTypeAppleM4V
        session!.outputFileType = AVFileTypeQuickTimeMovie
        return session!
    }
    
    
    func start(completion: (NSURL?) -> Void) {
        
        let exportPreset = AVAssetExportPreset640x480
        let exportFilePath:NSString = "~/Documents/TransitionsMovie.mov"
        let composition = AVMutableComposition()
        
        let moviesPath = [
            "FBHF9668",
            "FBIX1897",
            "JKUO2477",
            "RBDI3723",
            "XMQG0194"
        ]

        var allAssets = [AVAsset]()
        for movieName in moviesPath {
            let url = NSBundle.mainBundle().URLForResource(movieName, withExtension: "mp4")!
            allAssets.append(AVAsset(URL: url))
        }
        
        for asset in allAssets {
            print(asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize)
        }
        
        self.buildCompositionTracks2(composition, transitionDuration: transDuration, assetsWithVideoTracks: allAssets)
        
        let videoComposition = self.buildVideoCompositionAndInstructions2(composition, assets: allAssets, renderSize: cropSize)
        let exportSession = makeExportSession(exportPreset,
                                              videoComposition: videoComposition,
                                              composition: composition)
        
        // Make a expanded file path for export. Delete any previous generated file.
        let expandedFilePath = exportFilePath.stringByExpandingTildeInPath
        do {
            try NSFileManager.defaultManager().removeItemAtPath(expandedFilePath)
        } catch {}
        
        // Assign the output URL built from the expanded output file path.
        exportSession.outputURL = NSURL(fileURLWithPath: expandedFilePath, isDirectory:false)
        
        // Since export happens asyncrhonously then this command line tool can exit
        // before the export has completed unless we wait until the export has finished.
        let sessionWaitSemaphore = dispatch_semaphore_create(0)
        exportSession.exportAsynchronouslyWithCompletionHandler({
            dispatch_semaphore_signal(sessionWaitSemaphore)
            print(exportSession.error)
            dispatch_async(dispatch_get_main_queue(), {
                if exportSession.error == nil {
                    completion(exportSession.outputURL)
                } else {
                    completion(nil)
                }
            })
            
            return Void()
        })
        dispatch_semaphore_wait(sessionWaitSemaphore, DISPATCH_TIME_FOREVER)
        
        print("Export finished")
    }
}