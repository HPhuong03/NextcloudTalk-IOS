// From https://github.com/react-native-webrtc/react-native-webrtc (MIT License)
// SPDX-License-Identifier: MIT

#import <WebRTC/RTCVideoCapturer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CapturerEventsDelegate

/** Called when the capturer is ended and in an irrecoverable state. */
- (void)capturerDidEnd:(RTCVideoCapturer *)capturer;

@end

NS_ASSUME_NONNULL_END
