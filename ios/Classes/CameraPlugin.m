// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CameraPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <CoreMotion/CoreMotion.h>
#import <libkern/OSAtomic.h>
#import <UIKit/UIKit.h>

static FlutterError *getFlutterError(NSError *error) {
  return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)error.code]
                             message:error.localizedDescription
                             details:error.domain];
}

@interface FLTSavePhotoDelegate : NSObject <AVCapturePhotoCaptureDelegate>
@property(readonly, nonatomic) NSString *path;
@property(readonly, nonatomic) FlutterResult result;
@property(readonly, nonatomic) CMMotionManager *motionManager;
@property(readonly, nonatomic) AVCaptureDevicePosition cameraPosition;

- initWithPath:(NSString *)filename
            result:(FlutterResult)result
     motionManager:(CMMotionManager *)motionManager
    cameraPosition:(AVCaptureDevicePosition)cameraPosition;
@end

@interface FLTImageStreamHandler : NSObject <FlutterStreamHandler>
@property FlutterEventSink eventSink;
@end

@implementation FLTImageStreamHandler

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
  _eventSink = events;
  return nil;
}
@end

@implementation FLTSavePhotoDelegate {
  FLTSavePhotoDelegate *selfReference;
}

- initWithPath:(NSString *)path
            result:(FlutterResult)result
     motionManager:(CMMotionManager *)motionManager
    cameraPosition:(AVCaptureDevicePosition)cameraPosition {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _path = path;
  _result = result;
  _motionManager = motionManager;
  _cameraPosition = cameraPosition;
  selfReference = self;
  return self;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
                previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
                        resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                         bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings
                                   error:(NSError *)error {
  selfReference = nil;
  if (error) {
    _result(getFlutterError(error));
    return;
  }
  NSData *data = [AVCapturePhotoOutput
      JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer
                            previewPhotoSampleBuffer:previewPhotoSampleBuffer];
  UIImage *image = [UIImage imageWithCGImage:[UIImage imageWithData:data].CGImage
                                       scale:1.0
                                 orientation:[self getImageRotation]];
  bool success = [UIImageJPEGRepresentation(image, 1.0) writeToFile:_path atomically:YES];
  if (!success) {
    _result([FlutterError errorWithCode:@"IOError" message:@"Unable to write file" details:nil]);
    return;
  }
  _result(nil);
}

- (UIImageOrientation)getImageRotation {
  float const threshold = 45.0;
  BOOL (^isNearValue)(float value1, float value2) = ^BOOL(float value1, float value2) {
    return fabsf(value1 - value2) < threshold;
  };
  BOOL (^isNearValueABS)(float value1, float value2) = ^BOOL(float value1, float value2) {
    return isNearValue(fabsf(value1), fabsf(value2));
  };
  float yxAtan = (atan2(_motionManager.accelerometerData.acceleration.y,
                        _motionManager.accelerometerData.acceleration.x)) *
                 180 / M_PI;
  if (isNearValue(-90.0, yxAtan)) {
    return UIImageOrientationRight;
  } else if (isNearValueABS(180.0, yxAtan)) {
    return _cameraPosition == AVCaptureDevicePositionBack ? UIImageOrientationUp
                                                          : UIImageOrientationDown;
  } else if (isNearValueABS(0.0, yxAtan)) {
    return _cameraPosition == AVCaptureDevicePositionBack ? UIImageOrientationDown
                                                          : UIImageOrientationUp;
  } else if (isNearValue(90.0, yxAtan)) {
    return UIImageOrientationLeft;
  }
  return UIImageOrientationUp;
}
@end

typedef enum {
  veryLow,
  low,
  medium,
  high,
  veryHigh,
  ultraHigh,
  max,
} ResolutionPreset;

static ResolutionPreset getResolutionPresetForString(NSString *preset) {
  if ([preset isEqualToString:@"veryLow"]) {
    return veryLow;
  } else if ([preset isEqualToString:@"low"]) {
    return low;
  } else if ([preset isEqualToString:@"medium"]) {
    return medium;
  } else if ([preset isEqualToString:@"high"]) {
    return high;
  } else if ([preset isEqualToString:@"veryHigh"]) {
    return veryHigh;
  } else if ([preset isEqualToString:@"ultraHigh"]) {
    return ultraHigh;
  } else if ([preset isEqualToString:@"max"]) {
    return max;
  } else {
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSURLErrorUnknown
                                     userInfo:@{
                                       NSLocalizedDescriptionKey : [NSString
                                           stringWithFormat:@"Unknown resolution preset %@", preset]
                                     }];
    @throw error;
  }
}

@interface FLTCam : NSObject <FlutterTexture,
                              AVCaptureVideoDataOutputSampleBufferDelegate,
                              AVCaptureAudioDataOutputSampleBufferDelegate,
                              FlutterStreamHandler>
@property(readonly, nonatomic) int64_t textureId;
@property(nonatomic, copy) void (^onFrameAvailable)();
@property BOOL enableAudio;
@property (nonatomic) int flashMode;
@property BOOL enableAutoExposure;
@property BOOL autoFocusEnabled;
@property(assign, nonatomic) AVCaptureVideoStabilizationMode stabilizationMode;
@property(nonatomic) FlutterEventChannel *eventChannel;
@property(nonatomic) FLTImageStreamHandler *imageStreamHandler;
@property(nonatomic) FlutterEventSink eventSink;
@property(readonly, nonatomic) AVCaptureSession *captureSession;
@property(readonly, nonatomic) AVCaptureDevice *captureDevice;
@property(readonly, nonatomic) AVCapturePhotoOutput *capturePhotoOutput;
@property(readonly, nonatomic) AVCaptureVideoDataOutput *captureVideoOutput;
@property(readonly, nonatomic) AVCaptureInput *captureVideoInput;
@property(readonly) CVPixelBufferRef volatile latestPixelBuffer;
@property(readonly, nonatomic) CGSize previewSize;
@property(readonly, nonatomic) CGSize captureSize;
@property(strong, nonatomic) AVAssetWriter *videoWriter;
@property(strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property(strong, nonatomic) AVAssetWriterInput *audioWriterInput;
@property(strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
@property(strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property(strong, nonatomic) AVCaptureAudioDataOutput *audioOutput;
@property(assign, nonatomic) BOOL isRecording;
@property(assign, nonatomic) BOOL isRecordingPaused;
@property(assign, nonatomic) BOOL videoIsDisconnected;
@property(assign, nonatomic) BOOL audioIsDisconnected;
@property(assign, nonatomic) BOOL isAudioSetup;
@property(assign, nonatomic) BOOL isStreamingImages;
@property(assign, nonatomic) ResolutionPreset resolutionPreset;
@property(assign, nonatomic) CMTime lastVideoSampleTime;
@property(assign, nonatomic) CMTime lastAudioSampleTime;
@property(assign, nonatomic) CMTime videoTimeOffset;
@property(assign, nonatomic) CMTime audioTimeOffset;
@property(nonatomic) CMMotionManager *motionManager;
@property AVAssetWriterInputPixelBufferAdaptor *videoAdaptor;

- (instancetype)initWithCameraName:(NSString *)cameraName
                  resolutionPreset:(NSString *)resolutionPreset
                       enableAudio:(BOOL)enableAudio
                        flashMode:(int)flashMode
                  autoFocusEnabled:(int)autoFocusEnabled
                    enableAutoExposure:(BOOL)enableAutoExposure
                  stabilizationMode:(AVCaptureVideoStabilizationMode)stabilizationMode
                     dispatchQueue:(dispatch_queue_t)dispatchQueue
                             error:(NSError **)error;

- (void)start;
- (void)stop;
- (void)startVideoRecordingAtPath:(NSString *)path
                           result:(FlutterResult)result
                 orientationIndex:(int)orientationIndex;
- (void)stopVideoRecordingWithResult:(FlutterResult)result;
- (void)startImageStreamWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)stopImageStream;
- (void)captureToFile:(NSString *)filename result:(FlutterResult)result;
- (void)setFlashMode:(int)flashMode;
@end

@implementation FLTCam {
  dispatch_queue_t _dispatchQueue;
}
FourCharCode const videoFormat = kCVPixelFormatType_32BGRA;

- (instancetype)initWithCameraName:(NSString *)cameraName
                  resolutionPreset:(NSString *)resolutionPreset
                       enableAudio:(BOOL)enableAudio
                        flashMode:(int)flashMode
                    autoFocusEnabled:(int)autoFocusEnabled
                       enableAutoExposure:(BOOL)enableAutoExposure
                  stabilizationMode:(AVCaptureVideoStabilizationMode)stabilizationMode
                     dispatchQueue:(dispatch_queue_t)dispatchQueue
                             error:(NSError **)error {
  NSLog(@"###: init with camera name...");
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  @try {
    _resolutionPreset = getResolutionPresetForString(resolutionPreset);
    NSLog(@"###: get resolution preset without exceptions...");
  } @catch (NSError *e) {
    NSLog(@"###: exception in getting resolution preset: %@...", e.userInfo);
    *error = e;
  }
  _enableAudio = enableAudio;
  _flashMode = flashMode;
  _enableAutoExposure = enableAutoExposure;
  _autoFocusEnabled = autoFocusEnabled;
  _stabilizationMode = stabilizationMode; // Store the stabilization mode
  _dispatchQueue = dispatchQueue;
  _captureSession = [[AVCaptureSession alloc] init];

  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in devices) {
    if ([cameraName isEqual:@"1"] && device.position == AVCaptureDevicePositionFront) {
      NSLog(@"###: asked for the front camera...");
      _captureDevice = device;
    } else if ([cameraName isEqual:@"0"] && device.position == AVCaptureDevicePositionBack) {
      NSLog(@"###: asked for the back camera...");
      _captureDevice = device;
    }
  }

  AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
  if (authStatus == AVAuthorizationStatusAuthorized) {
    NSLog(@"###: Authorization");
  } else if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted) {
    NSLog(@"###: Status denied or restricted");
  } else {
    NSLog(@"###: Unauthorization");
  }

  NSError *localError = nil;
  _captureVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&localError];
  if (localError) {
    *error = localError;
    NSLog(@"###: capture video input error: %@...", localError.userInfo);
    return nil;
  }

  _captureVideoOutput = [AVCaptureVideoDataOutput new];
  _captureVideoOutput.videoSettings =
      @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(videoFormat)};
  [_captureVideoOutput setAlwaysDiscardsLateVideoFrames:YES];
  [_captureVideoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

  AVCaptureConnection *connection =
      [AVCaptureConnection connectionWithInputPorts:_captureVideoInput.ports
                                             output:_captureVideoOutput];
  if ([_captureDevice position] == AVCaptureDevicePositionFront) {
    connection.videoMirrored = YES;
  }
  if (connection.isVideoOrientationSupported) {
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    NSLog(@"### Video orientation set to Portrait.");
  } else {
    NSLog(@"### Video orientation is not supported.");
  }

  // Apply video stabilization if supported
  if ([connection isVideoStabilizationSupported]) {
    NSLog(@"### Video stabilization supported, setting mode to %ld", (long)_stabilizationMode);
    connection.preferredVideoStabilizationMode = _stabilizationMode;
  } else {
    NSLog(@"### Video stabilization not supported on this device.");
  }

  [_captureSession addInputWithNoConnections:_captureVideoInput];
  [_captureSession addOutputWithNoConnections:_captureVideoOutput];
  [_captureSession addConnection:connection];

  _capturePhotoOutput = [AVCapturePhotoOutput new];
  [_capturePhotoOutput setHighResolutionCaptureEnabled:YES];
  [_captureSession addOutput:_capturePhotoOutput];
  _motionManager = [[CMMotionManager alloc] init];
  [_motionManager startAccelerometerUpdates];

  [self setFlashMode:flashMode];
  if (enableAutoExposure) {
    [self setAutoExposureMode:enableAutoExposure];
  }
  if (autoFocusEnabled) {
    [self setAutoFocus:autoFocusEnabled];
  }

  [self setCaptureSessionPreset:_resolutionPreset];
  return self;
}

- (void)start {
  [_captureSession startRunning];
}

- (void)stop {
  [_captureSession stopRunning];
}

- (void)captureToFile:(NSString *)path result:(FlutterResult)result {
  AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
  if (_resolutionPreset == max) {
    [settings setHighResolutionPhotoEnabled:YES];
  }
  if (_flashMode == 0) {
    [settings setFlashMode:AVCaptureFlashModeOn];
  } else if (_flashMode == 2) {
    [settings setFlashMode:AVCaptureFlashModeAuto];
  } else if (_flashMode == 3) {
    [settings setFlashMode:AVCaptureFlashModeOff];
  }
  [_capturePhotoOutput
      capturePhotoWithSettings:settings
                      delegate:[[FLTSavePhotoDelegate alloc] initWithPath:path
                                                                   result:result
                                                            motionManager:_motionManager
                                                           cameraPosition:_captureDevice.position]];
}

- (void)setCaptureSessionPreset:(ResolutionPreset)resolutionPreset {
  switch (resolutionPreset) {
    case max:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        _previewSize =
            CGSizeMake(_captureDevice.activeFormat.highResolutionStillImageDimensions.width,
                       _captureDevice.activeFormat.highResolutionStillImageDimensions.height);
        break;
      }
    case ultraHigh:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset3840x2160;
        _previewSize = CGSizeMake(3840, 2160);
        break;
      }
    case veryHigh:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
        _previewSize = CGSizeMake(1920, 1080);
        break;
      }
    case high:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
        _previewSize = CGSizeMake(1280, 720);
        break;
      }
    case medium:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        _previewSize = CGSizeMake(640, 480);
        break;
      }
    case low:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset352x288]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset352x288;
        _previewSize = CGSizeMake(352, 288);
        break;
      }
    default:
      if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetLow]) {
        _captureSession.sessionPreset = AVCaptureSessionPresetLow;
        _previewSize = CGSizeMake(352, 288);
      } else {
        NSError *error =
            [NSError errorWithDomain:NSCocoaErrorDomain
                                code:NSURLErrorUnknown
                            userInfo:@{
                              NSLocalizedDescriptionKey :
                                  @"No capture session available for current capture session."
                            }];
        @throw error;
      }
  }
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
  if (output == _captureVideoOutput) {
    CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFRetain(newBuffer);
    CVPixelBufferRef old = _latestPixelBuffer;
    while (!OSAtomicCompareAndSwapPtrBarrier(old, newBuffer, (void **)&_latestPixelBuffer)) {
      old = _latestPixelBuffer;
    }
    if (old != nil) {
      CFRelease(old);
    }
    if (_onFrameAvailable) {
      _onFrameAvailable();
    }
  }
  if (!CMSampleBufferDataIsReady(sampleBuffer)) {
    _eventSink(@{
      @"event" : @"error",
      @"errorDescription" : @"sample buffer is not ready. Skipping sample"
    });
    return;
  }
  if (_isStreamingImages) {
    if (_imageStreamHandler.eventSink) {
      CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

      size_t imageWidth = CVPixelBufferGetWidth(pixelBuffer);
      size_t imageHeight = CVPixelBufferGetHeight(pixelBuffer);

      NSMutableArray *planes = [NSMutableArray array];
      const Boolean isPlanar = CVPixelBufferIsPlanar(pixelBuffer);
      size_t planeCount = isPlanar ? CVPixelBufferGetPlaneCount(pixelBuffer) : 1;

      for (int i = 0; i < planeCount; i++) {
        void *planeAddress;
        size_t bytesPerRow;
        size_t height;
        size_t width;

        if (isPlanar) {
          planeAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i);
          bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
          height = CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
          width = CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
        } else {
          planeAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
          bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
          height = CVPixelBufferGetHeight(pixelBuffer);
          width = CVPixelBufferGetWidth(pixelBuffer);
        }

        NSNumber *length = @(bytesPerRow * height);
        NSData *bytes = [NSData dataWithBytes:planeAddress length:length.unsignedIntegerValue];

        NSMutableDictionary *planeBuffer = [NSMutableDictionary dictionary];
        planeBuffer[@"bytesPerRow"] = @(bytesPerRow);
        planeBuffer[@"width"] = @(width);
        planeBuffer[@"height"] = @(height);
        planeBuffer[@"bytes"] = [FlutterStandardTypedData typedDataWithBytes:bytes];

        [planes addObject:planeBuffer];
      }

      NSMutableDictionary *imageBuffer = [NSMutableDictionary dictionary];
      imageBuffer[@"width"] = [NSNumber numberWithUnsignedLong:imageWidth];
      imageBuffer[@"height"] = [NSNumber numberWithUnsignedLong:imageHeight];
      imageBuffer[@"format"] = @(videoFormat);
      imageBuffer[@"planes"] = planes;

      _imageStreamHandler.eventSink(imageBuffer);
      CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
  }
  if (_isRecording && !_isRecordingPaused) {
    if (_videoWriter.status == AVAssetWriterStatusFailed) {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
      });
      return;
    }

    CFRetain(sampleBuffer);
    CMTime currentSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

    if (_videoWriter.status != AVAssetWriterStatusWriting) {
      [_videoWriter startWriting];
      [_videoWriter startSessionAtSourceTime:currentSampleTime];
    }

    if (output == _captureVideoOutput) {
      if (_videoIsDisconnected) {
        _videoIsDisconnected = NO;
        if (_videoTimeOffset.value == 0) {
          _videoTimeOffset = CMTimeSubtract(currentSampleTime, _lastVideoSampleTime);
        } else {
          CMTime offset = CMTimeSubtract(currentSampleTime, _lastVideoSampleTime);
          _videoTimeOffset = CMTimeAdd(_videoTimeOffset, offset);
        }
        return;
      }

      _lastVideoSampleTime = currentSampleTime;
      CVPixelBufferRef nextBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      CMTime nextSampleTime = CMTimeSubtract(_lastVideoSampleTime, _videoTimeOffset);
      [_videoAdaptor appendPixelBuffer:nextBuffer withPresentationTime:nextSampleTime];
    } else {
      CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
      if (dur.value > 0) {
        currentSampleTime = CMTimeAdd(currentSampleTime, dur);
      }
      if (_audioIsDisconnected) {
        _audioIsDisconnected = NO;
        if (_audioTimeOffset.value == 0) {
          _audioTimeOffset = CMTimeSubtract(currentSampleTime, _lastAudioSampleTime);
        } else {
          CMTime offset = CMTimeSubtract(currentSampleTime, _lastAudioSampleTime);
          _audioTimeOffset = CMTimeAdd(_audioTimeOffset, offset);
        }
        return;
      }

      _lastAudioSampleTime = currentSampleTime;
      if (_audioTimeOffset.value != 0) {
        CFRelease(sampleBuffer);
        sampleBuffer = [self adjustTime:sampleBuffer by:_audioTimeOffset];
      }
      [self newAudioSample:sampleBuffer];
    }
    CFRelease(sampleBuffer);
  }
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset {
  CMItemCount count;
  CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
  CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
  CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
  for (CMItemCount i = 0; i < count; i++) {
    pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
    pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
  }
  CMSampleBufferRef sout;
  CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
  free(pInfo);
  return sout;
}

- (void)newVideoSample:(CMSampleBufferRef)sampleBuffer {
  if (_videoWriter.status != AVAssetWriterStatusWriting) {
    if (_videoWriter.status == AVAssetWriterStatusFailed) {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
      });
    }
    return;
  }
  if (_videoWriterInput.readyForMoreMediaData) {
    if (![_videoWriterInput appendSampleBuffer:sampleBuffer]) {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" :
            [NSString stringWithFormat:@"%@", @"Unable to write to video input"]
      });
    }
  }
}

- (void)newAudioSample:(CMSampleBufferRef)sampleBuffer {
  if (_videoWriter.status != AVAssetWriterStatusWriting) {
    if (_videoWriter.status == AVAssetWriterStatusFailed) {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" : [NSString stringWithFormat:@"%@", _videoWriter.error]
      });
    }
    return;
  }
  if (_audioWriterInput.readyForMoreMediaData) {
    if (![_audioWriterInput appendSampleBuffer:sampleBuffer]) {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" :
            [NSString stringWithFormat:@"%@", @"Unable to write to audio input"]
      });
    }
  }
}

- (void)close {
  [_captureSession stopRunning];
  for (AVCaptureInput *input in [_captureSession inputs]) {
    [_captureSession removeInput:input];
  }
  for (AVCaptureOutput *output in [_captureSession outputs]) {
    [_captureSession removeOutput:output];
  }
}

- (void)dealloc {
  if (_latestPixelBuffer) {
    CFRelease(_latestPixelBuffer);
  }
  [_motionManager stopAccelerometerUpdates];
}

- (CVPixelBufferRef)copyPixelBuffer {
  CVPixelBufferRef pixelBuffer = _latestPixelBuffer;
  while (!OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, (void **)&_latestPixelBuffer)) {
    pixelBuffer = _latestPixelBuffer;
  }
  return pixelBuffer;
}

- (FlutterError *_Nullable)onCancelWithArguments:(id _Nullable)arguments {
  _eventSink = nil;
  return nil;
}

- (FlutterError *_Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
  _eventSink = events;
  return nil;
}

- (void)startVideoRecordingAtPath:(NSString *)path
                           result:(FlutterResult)result
                 orientationIndex:(int)orientationIndex {
  NSLog(@"###: Orientation index received: %d", orientationIndex);
  if (!_isRecording) {
    if (![self setupWriterForPath:path orientationIndex:orientationIndex]) {
      _eventSink(@{@"event" : @"error", @"errorDescription" : @"Setup Writer Failed"});
      return;
    }
    _isRecording = YES;
    _isRecordingPaused = NO;
    _videoTimeOffset = CMTimeMake(0, 1);
    _audioTimeOffset = CMTimeMake(0, 1);
    _videoIsDisconnected = NO;
    _audioIsDisconnected = NO;
    result(nil);
  } else {
    _eventSink(@{@"event" : @"error", @"errorDescription" : @"Video is already recording!"});
  }
}

- (void)stopVideoRecordingWithResult:(FlutterResult)result {
  if (_isRecording) {
    _isRecording = NO;
    if (_videoWriter.status != AVAssetWriterStatusUnknown) {
      [_videoWriter finishWritingWithCompletionHandler:^{
        if (self->_videoWriter.status == AVAssetWriterStatusCompleted) {
          result(nil);
        } else {
          self->_eventSink(@{
            @"event" : @"error",
            @"errorDescription" : @"AVAssetWriter could not finish writing!"
          });
        }
      }];
    }
  } else {
    NSError *error =
        [NSError errorWithDomain:NSCocoaErrorDomain
                            code:NSURLErrorResourceUnavailable
                        userInfo:@{NSLocalizedDescriptionKey : @"Video is not recording!"}];
    result(getFlutterError(error));
  }
}

- (void)pauseVideoRecording {
  _isRecordingPaused = YES;
  _videoIsDisconnected = YES;
  _audioIsDisconnected = YES;
}

- (void)resumeVideoRecording {
  _isRecordingPaused = NO;
}

- (void)startImageStreamWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  if (!_isStreamingImages) {
    FlutterEventChannel *eventChannel =
        [FlutterEventChannel eventChannelWithName:@"plugins.flutter.io/camera/imageStream"
                                  binaryMessenger:messenger];
    _imageStreamHandler = [[FLTImageStreamHandler alloc] init];
    [eventChannel setStreamHandler:_imageStreamHandler];
    _isStreamingImages = YES;
  } else {
    _eventSink(
        @{@"event" : @"error", @"errorDescription" : @"Images from camera are already streaming!"});
  }
}

- (void)stopImageStream {
  if (_isStreamingImages) {
    _isStreamingImages = NO;
    _imageStreamHandler = nil;
  } else {
    _eventSink(
        @{@"event" : @"error", @"errorDescription" : @"Images from camera are not streaming!"});
  }
}

- (bool)hasFlash {
  AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  return ([device hasFlash] && [device hasFlash]);
}

- (void)setFlashMode:(int)flashMode {
  [self setFlashMode:flashMode level:1.0];
}

- (void)setFlashMode:(int)flashMode level:(float)level {
  _flashMode = flashMode;
}

- (void)setAutoExposureMode:(BOOL)enable {
  [_captureDevice lockForConfiguration:nil];
  if (enable) {
    if ([_captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
      [_captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
  } else {
    [_captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
  }
  [_captureDevice unlockForConfiguration];
}

- (void)setAutoFocus:(BOOL)enable {
  NSError *error = nil;
  if (_captureDevice == nil) {
    return;
  }
  if (![_captureDevice lockForConfiguration:&error]) {
    return;
  }
  if (enable) {
    if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      [_captureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
  }
  [_captureDevice unlockForConfiguration];
}

- (void)zoom:(double)zoom {
  NSError *error = nil;
  if (_captureDevice == nil) {
    return;
  }
  if (![_captureDevice lockForConfiguration:&error]) {
    return;
  }
  float maxZoom = _captureDevice.activeFormat.videoMaxZoomFactor;
  if (zoom > maxZoom) {
    _captureDevice.videoZoomFactor = maxZoom;
  } else {
    _captureDevice.videoZoomFactor = (float)zoom;
  }
  [_captureDevice unlockForConfiguration];
}

- (BOOL)setupWriterForPath:(NSString *)path orientationIndex:(int)orientationIndex {
  NSError *error = nil;
  NSURL *outputURL;
  if (path != nil) {
    outputURL = [NSURL fileURLWithPath:path];
  } else {
    return NO;
  }

  if (_enableAudio && !_isAudioSetup) {
    [self setUpCaptureSessionForAudio];
  }

  _videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL
                                           fileType:AVFileTypeQuickTimeMovie
                                              error:&error];
  NSParameterAssert(_videoWriter);
  if (error) {
    _eventSink(@{@"event" : @"error", @"errorDescription" : error.description});
    return NO;
  }

  NSDictionary *videoSettings = @{
    AVVideoCodecKey : AVVideoCodecH264,
    AVVideoWidthKey : [NSNumber numberWithInt:_previewSize.height],
    AVVideoHeightKey : [NSNumber numberWithInt:_previewSize.width],
  };

  _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                         outputSettings:videoSettings];
  NSLog(@"###: Device Orientation is: %d", orientationIndex);

  CGAffineTransform transform = CGAffineTransformIdentity;
  switch (orientationIndex) {
    case 0:
      transform = CGAffineTransformIdentity;
      break;
    case 1:
      transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI_2);
      break;
    case 2:
      transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI);
      break;
    case 3:
      transform = CGAffineTransformRotate(CGAffineTransformIdentity, -M_PI_2);
      break;
    default:
      break;
  }

  _videoWriterInput.transform = transform;

  _videoAdaptor = [AVAssetWriterInputPixelBufferAdaptor
      assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput
                                 sourcePixelBufferAttributes:@{
                                   (NSString *)kCVPixelBufferPixelFormatTypeKey : @(videoFormat)
                                 }];

  NSParameterAssert(_videoWriterInput);
  _videoWriterInput.expectsMediaDataInRealTime = YES;

  if (_enableAudio) {
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    NSDictionary *audioOutputSettings = @{
      AVFormatIDKey : @(kAudioFormatMPEG4AAC),
      AVSampleRateKey : @(44100.0),
      AVNumberOfChannelsKey : @(1),
      AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)],
    };

    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                           outputSettings:audioOutputSettings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    [_videoWriter addInput:_audioWriterInput];
    [_audioOutput setSampleBufferDelegate:self queue:_dispatchQueue];
  }

  [_videoWriter addInput:_videoWriterInput];
  [_captureVideoOutput setSampleBufferDelegate:self queue:_dispatchQueue];

  return YES;
}

- (void)setUpCaptureSessionForAudio {
  NSError *error = nil;
  AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
  AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice
                                                                           error:&error];
  if (error) {
    _eventSink(@{@"event" : @"error", @"errorDescription" : error.description});
  }
  _audioOutput = [[AVCaptureAudioDataOutput alloc] init];

  if ([_captureSession canAddInput:audioInput]) {
    [_captureSession addInput:audioInput];
    if ([_captureSession canAddOutput:_audioOutput]) {
      [_captureSession addOutput:_audioOutput];
      _isAudioSetup = YES;
    } else {
      _eventSink(@{
        @"event" : @"error",
        @"errorDescription" : @"Unable to add Audio input/output to session capture"
      });
      _isAudioSetup = NO;
    }
  }
}
@end

@interface CameraPlugin ()
@property(readonly, nonatomic) NSObject<FlutterTextureRegistry> *registry;
@property(readonly, nonatomic) NSObject<FlutterBinaryMessenger> *messenger;
@property(readonly, nonatomic) FLTCam *camera;
@end

@implementation CameraPlugin {
  dispatch_queue_t _dispatchQueue;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/camera"
                                  binaryMessenger:[registrar messenger]];
  CameraPlugin *instance = [[CameraPlugin alloc] initWithRegistry:[registrar textures]
                                                        messenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry
                       messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _registry = registry;
  _messenger = messenger;
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if (_dispatchQueue == nil) {
    _dispatchQueue = dispatch_queue_create("io.flutter.camera.dispatchqueue", NULL);
  }
  dispatch_async(_dispatchQueue, ^{
    [self handleMethodCallAsync:call result:result];
  });
}

- (void)handleMethodCallAsync:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"availableCameras" isEqualToString:call.method]) {
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
        discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                              mediaType:AVMediaTypeVideo
                               position:AVCaptureDevicePositionUnspecified];
    NSArray<AVCaptureDevice *> *devices = discoverySession.devices;
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *reply =
        [[NSMutableArray alloc] initWithCapacity:devices.count];
    for (AVCaptureDevice *device in devices) {
      NSString *lensFacing;
      switch ([device position]) {
        case AVCaptureDevicePositionBack:
          lensFacing = @"back";
          break;
        case AVCaptureDevicePositionFront:
          lensFacing = @"front";
          break;
        case AVCaptureDevicePositionUnspecified:
          lensFacing = @"external";
          break;
      }
      [reply addObject:@{
        @"name" : [device uniqueID],
        @"lensFacing" : lensFacing,
        @"sensorOrientation" : @90,
      }];
    }
    result(reply);
  } else if ([@"initialize" isEqualToString:call.method]) {
    NSLog(@"cameraName: %@", call.arguments[@"cameraName"]);
    NSString *cameraName = call.arguments[@"cameraName"];
    NSString *resolutionPreset = call.arguments[@"resolutionPreset"];
    NSNumber *enableAudio = call.arguments[@"enableAudio"];
    NSNumber *flashMode = call.arguments[@"flashMode"];
    NSNumber *enableAutoExposure = call.arguments[@"enableAutoExposure"];
    NSNumber *autoFocusEnabled = call.arguments[@"autoFocusEnabled"];

    NSError *error;
    FLTCam *cam = [[FLTCam alloc] initWithCameraName:cameraName
                                    resolutionPreset:resolutionPreset
                                         enableAudio:[enableAudio boolValue]
                                          flashMode:[flashMode intValue]
                                    autoFocusEnabled:[autoFocusEnabled boolValue]
                                    enableAutoExposure:[enableAutoExposure boolValue]
                                    stabilizationMode:AVCaptureVideoStabilizationModeStandard // Change this value to update stabilizer mode
                                       dispatchQueue:_dispatchQueue
                                               error:&error];
    if (error) {
      NSLog(@"Error Error Error Error %@ %@", error.userInfo, error);
      result(getFlutterError(error));
    } else {
      if (_camera) {
        [_camera close];
      }
      int64_t textureId = [_registry registerTexture:cam];
      _camera = cam;
      cam.onFrameAvailable = ^{
        [_registry textureFrameAvailable:textureId];
      };
      FlutterEventChannel *eventChannel = [FlutterEventChannel
          eventChannelWithName:[NSString
                                   stringWithFormat:@"flutter.io/cameraPlugin/cameraEvents%lld",
                                                    textureId]
               binaryMessenger:_messenger];
      dispatch_async(dispatch_get_main_queue(), ^{
        [eventChannel setStreamHandler:cam];
      });
      cam.eventChannel = eventChannel;
      result(@{
        @"textureId" : @(textureId),
        @"previewWidth" : @(cam.previewSize.width),
        @"previewHeight" : @(cam.previewSize.height),
        @"captureWidth" : @(cam.captureSize.width),
        @"captureHeight" : @(cam.captureSize.height),
      });
      [cam start];
    }
  } else if ([@"startImageStream" isEqualToString:call.method]) {
    [_camera startImageStreamWithMessenger:_messenger];
    result(nil);
  } else if ([@"stopImageStream" isEqualToString:call.method]) {
    [_camera stopImageStream];
    result(nil);
  } else if ([@"pauseVideoRecording" isEqualToString:call.method]) {
    [_camera pauseVideoRecording];
    result(nil);
  } else if ([@"resumeVideoRecording" isEqualToString:call.method]) {
    [_camera resumeVideoRecording];
    result(nil);
  } else if ([@"hasFlash" isEqualToString:call.method]) {
    result([NSNumber numberWithBool:[_camera hasFlash]]);
  } else if ([@"setFlashMode" isEqualToString:call.method]) {
    NSNumber *flashMode = call.arguments[@"flashMode"];
    NSLog(@"###: FLASH MODE %@", flashMode);
    int myInteger = [flashMode integerValue];
    if (myInteger == 2) {
      NSLog(@"OPEN FLASH");
      double torchLevel = 0.9;
      AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      if ([device hasTorch]) {
        NSLog(@"###:111111111111");
        [device lockForConfiguration:nil];
        NSLog(@"###:22222222222");
        if (torchLevel <= 0.0) {
          [device setTorchMode:AVCaptureTorchModeOff];
          NSLog(@"###:3333333333");
        } else {
          if (torchLevel >= 1.0) {
            torchLevel = AVCaptureMaxAvailableTorchLevel;
            NSLog(@"###:444444444444");
          }
          BOOL success = [device setTorchModeOnWithLevel:torchLevel error:nil];
          NSLog(@"###:5555555555555");
          NSLog(@"###: open torch state %d", success);
        }
        NSLog(@"###: torch level %ld", (long)torchLevel);
        [device unlockForConfiguration];
        NSLog(@"###:666666666666");
      }
    } else {
      NSLog(@"###:00000000000");
      double torchLevel = 0.0;
      AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      if ([device hasTorch]) {
        NSLog(@"###:111111111111");
        [device lockForConfiguration:nil];
        NSLog(@"###:22222222222");
        if (torchLevel <= 0.0) {
          [device setTorchMode:AVCaptureTorchModeOff];
          NSLog(@"###:3333333333");
        } else {
          if (torchLevel >= 1.0) {
            torchLevel = AVCaptureMaxAvailableTorchLevel;
            NSLog(@"###:444444444444");
          }
          BOOL success = [device setTorchModeOnWithLevel:torchLevel error:nil];
          NSLog(@"###:5555555555555");
          NSLog(@"###: open torch state %d", success);
        }
        NSLog(@"###: torch level %ld", (long)torchLevel);
        [device unlockForConfiguration];
        NSLog(@"###:666666666666");
      }
      [_camera setFlashMode:[flashMode intValue]];
    }
    result(nil);
  } else if ([@"autoExposureOn" isEqualToString:call.method]) {
    [_camera setAutoExposureMode:true];
    result(nil);
  } else if ([@"autoExposureOff" isEqualToString:call.method]) {
    [_camera setAutoExposureMode:false];
  } else if ([@"zoom" isEqualToString:call.method]) {
    NSNumber *step = call.arguments[@"step"];
    [_camera zoom:[step doubleValue]];
    result(nil);
  } else {
    NSDictionary *argsMap = call.arguments;
    NSUInteger textureId = ((NSNumber *)argsMap[@"textureId"]).unsignedIntegerValue;

    if ([@"takePicture" isEqualToString:call.method]) {
      [_camera captureToFile:call.arguments[@"path"] result:result];
    } else if ([@"dispose" isEqualToString:call.method]) {
      [_registry unregisterTexture:textureId];
      [_camera close];
      _dispatchQueue = nil;
      result(nil);
    } else if ([@"prepareForVideoRecording" isEqualToString:call.method]) {
      [_camera setUpCaptureSessionForAudio];
      result(nil);
    } else if ([@"startVideoRecording" isEqualToString:call.method]) {
      [_camera startVideoRecordingAtPath:call.arguments[@"filePath"]
                                  result:result
                        orientationIndex:[call.arguments[@"orientationIndex"] intValue]];
    } else if ([@"stopVideoRecording" isEqualToString:call.method]) {
      [_camera stopVideoRecordingWithResult:result];
    } else {
      result(FlutterMethodNotImplemented);
    }
  }
}

@end
