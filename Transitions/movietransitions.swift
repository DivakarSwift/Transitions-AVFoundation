//
//  main.swift
//  mutablecomposition
//
//  Created by Kevin Meaney on 24/08/2015.
//  Copyright (c) 2015 Kevin Meaney. All rights reserved.
//

import Foundation

// !/usr/bin/env swift
// If you want to run this file from the command line uncomment the above line
// so that the '' symbol is at the beginning of the line.
//  Created by Kevin Meaney on 20/11/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.
// The first part of the script is basically config options.

import AVFoundation


class MovieTransitions {
    // Set the transition duration time to two seconds.
    let transDuration = CMTimeMake(2, 1)
    
    // The movies below have the same dimensions as the movie I want to generate
    let movieSize = CGSizeMake(800, 800)
    let cropSize = CGSizeMake(800, 800)
    
    // This is the preset applied to the AVAssetExportSession.
    // If the passthrough preset is used then the created movie file has two video
    // tracks but the transitions between the segments in each track are lost.
    // Other presets will generate a file with a single video track with the
    // transitions applied before export happens.
    // let exportPreset = AVAssetExportPresetPassthrough
    let exportPreset = AVAssetExportPreset640x480
    
    // Path and file name to where the generated movie file will be created.
    // If a previous file was at this location it will be deleted before the new
    // file is generated. BEWARE
    let exportFilePath:NSString = "~/Documents/TransitionsMovie.mov"
    
    // Create the list of paths to movie files that generated movie will transition between.
    // The movies need to not have any copy protection.
    
    static let movieFilePaths = [
        "FBHF9668",
        "FBIX1897",
        "JKUO2477",
        "RBDI3723",
        "XMQG0194"
    ]
    
    // Convert the file paths into URLS after expanding any tildes in the path
    static let urls = movieFilePaths.map({ (filePath) -> NSURL in
        
        return NSBundle.mainBundle().URLForResource(filePath, withExtension: "mp4")!
    })
    
    // Make movie assets from the URLs.
    let movieAssets:[AVURLAsset] = urls.map { AVURLAsset(URL:$0, options:.None) }
    
    // Create the mutable composition that we are going to build up.
    var composition = AVMutableComposition()
    
    // Function to build the composition tracks.
    func buildCompositionTracks(composition: AVMutableComposition,
                                transitionDuration: CMTime,
                                assetsWithVideoTracks: [AVURLAsset]) -> Void {
        let compositionTrackA = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let compositionTrackB = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let videoTracks = [compositionTrackA, compositionTrackB]
        
        var cursorTime = kCMTimeZero
        
        for i in 0..<assetsWithVideoTracks.count {
            let trackIndex = i % 2
            let currentTrack = videoTracks[trackIndex]
            
//            print("\(assetsWithVideoTracks[i].tracksWithMediaType(AVMediaTypeVideo)[0].naturalSize) \(currentTrack.naturalSize)")
            
            
            let assetTrack = assetsWithVideoTracks[i].tracksWithMediaType(AVMediaTypeVideo)[0]
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
    
    // Function to calculate both the pass through time and the transition time ranges
    func calculateTimeRanges(transitionDuration: CMTime,
                             assetsWithVideoTracks: [AVURLAsset])
        -> (passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue]) {
            
            var passThroughTimeRanges:[NSValue] = [NSValue]()
            var transitionTimeRanges:[NSValue] = [NSValue]()
            var cursorTime = kCMTimeZero
            
            for i in 0..<assetsWithVideoTracks.count
            {
                let asset = assetsWithVideoTracks[i]
                var timeRange = CMTimeRangeMake(cursorTime, asset.duration)
                
                if i > 0 {
                    timeRange.start = CMTimeAdd(timeRange.start, transDuration)
                    timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
                }
                
                if i + 1 < assetsWithVideoTracks.count {
                    timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
                }
                
                passThroughTimeRanges.append(NSValue(CMTimeRange: timeRange))
                cursorTime = CMTimeAdd(cursorTime, asset.duration)
                cursorTime = CMTimeSubtract(cursorTime, transDuration)
                // println("cursorTime.value: \(cursorTime.value)")
                // println("cursorTime.timescale: \(cursorTime.timescale)")
                
                if i + 1 < assetsWithVideoTracks.count {
                    timeRange = CMTimeRangeMake(cursorTime, transDuration)
                    // println("timeRange start value: \(timeRange.start.value)")
                    // println("timeRange start timescale: \(timeRange.start.timescale)")
                    transitionTimeRanges.append(NSValue(CMTimeRange: timeRange))
                }
            }
            return (passThroughTimeRanges, transitionTimeRanges)
    }
    
    // Build the video composition and instructions.
    func buildVideoCompositionAndInstructions(
        composition: AVMutableComposition,
        assets: [AVAsset],
        passThroughTimeRanges: [NSValue],
        transitionTimeRanges: [NSValue],
        renderSize: CGSize) -> AVMutableVideoComposition {
        
        // Create a mutable composition instructions object
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        
        // Get the list of asset tracks and tell compiler they are a list of asset tracks.
        let tracks = composition.tracksWithMediaType(AVMediaTypeVideo)
        
        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOfAsset: composition)
        
        // Now create the instructions from the various time ranges.
        var nextOriginalSize = CGSize.zero
        var asset: AVAsset!
        var originalSize: CGSize!
        var trackIndex: Int = 0
        
        for i in 0..<assets.count
        {
            asset = assets[i]
            originalSize = asset.tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize
            if i < assets.count - 1 {
                nextOriginalSize = assets[i + 1].tracksWithMediaType(AVMediaTypeVideo).first!.naturalSize
            }
            trackIndex = i % 2
            let currentTrack = tracks[trackIndex]
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = passThroughTimeRanges[i].CMTimeRangeValue
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: currentTrack)
            instruction.layerInstructions = [layerInstruction]
            compositionInstructions.append(instruction)
            setLayerInstructions(layerInstruction, timeStart: instruction.timeRange.start, videoTrack: currentTrack, originalSize: originalSize)
            
            if i < transitionTimeRanges.count {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = transitionTimeRanges[i].CMTimeRangeValue
                
                // Determine the foreground and background tracks.
                let fgTrack = tracks[trackIndex]
                let bgTrack = tracks[1 - trackIndex]
                
                // Create the "from layer" instruction.
                let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: fgTrack)
                
                // Make the opacity ramp and apply it to the from layer instruction.
                fLInstruction.setOpacityRampFromStartOpacity(1.0, toEndOpacity:0.0,
                                                             timeRange: instruction.timeRange)
                
                
                // Create the "to layer" instruction. Do I need this?
                let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: bgTrack)
                instruction.layerInstructions = [fLInstruction, tLInstruction]
                compositionInstructions.append(instruction)
                
                let transformResult = setLayerInstructions(fLInstruction, timeStart: instruction.timeRange.start, videoTrack: fgTrack, originalSize: originalSize)
                setLayerInstructions(tLInstruction, timeStart: CMTimeSubtract(instruction.timeRange.start, transDuration), videoTrack: bgTrack, originalSize: nextOriginalSize)
                
                let animatedOutTransform = CGAffineTransformMakeTranslation(cropSize.width * 2, 0)
                fLInstruction.setTransformRampFromStartTransform(transformResult, toEndTransform: CGAffineTransformConcat(transformResult, animatedOutTransform), timeRange: instruction.timeRange)
                
            }
        }
        
        videoComposition.instructions = compositionInstructions
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTimeMake(1, 30)
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
        // Now call the functions to do the preperation work for preparing a composition to export.
        // First create the tracks needed for the composition.
        buildCompositionTracks(composition,
                               transitionDuration: transDuration,
                               assetsWithVideoTracks: movieAssets)
        
        // Create the passthru and transition time ranges.
        let timeRanges = calculateTimeRanges(transDuration,
                                             assetsWithVideoTracks: movieAssets)
        
        // Create the instructions for which movie to show and create the video composition.
        let videoComposition = buildVideoCompositionAndInstructions(
            composition,
            assets: movieAssets,
            passThroughTimeRanges: timeRanges.passThroughTimeRanges,
            transitionTimeRanges: timeRanges.transitionTimeRanges,
            renderSize: movieSize)
        
        // Make the export session object that we'll use to export the transition movie
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