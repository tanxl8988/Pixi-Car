//
//  APKGetLiveUrlResponseObjectHandler.m
//  Aigo
//
//  Created by Mac on 17/7/21.
//  Copyright © 2017年 APK. All rights reserved.
//

#import "APKGetLiveInfoResponseObjectHandler.h"

static NSString *DEFAULT_RTSP_URL_AV1   = @"/liveRTSP/av1" ;
static NSString *DEFAULT_RTSP_URL_V1    = @"/liveRTSP/v1" ;
static NSString *DEFAULT_RTSP_URL_AV2    = @"/liveRTSP/av2" ;
static NSString *DEFAULT_RTSP_URL_AV4    = @"/liveRTSP/av4" ;
static NSString *DEFAULT_MJPEG_PUSH_URL = @"/cgi-bin/liveMJPEG" ;

@implementation APKGetLiveInfoResponseObjectHandler

- (void)handle:(id)responseObject successCommandHandler:(APKSuccessCommandHandler)successCommandHandler failureCommandHandler:(APKFailureCommandHandler)failureCommandHandler{
    
    NSData *data = responseObject;
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    int             rtsp;
    NSDictionary    *dict;
    dict = [self buildResultDictionary:result];
    if (dict == nil) return;
    rtsp        = [[dict objectForKey:@"Camera.Preview.RTSP.av"] intValue];
    
    NSString *liveUrlString = nil;
    if (rtsp == 1) {
        liveUrlString = [NSString stringWithFormat:@"rtsp://192.72.1.1%@", DEFAULT_RTSP_URL_AV1];
    }else if (rtsp == 2) {
        liveUrlString = [NSString stringWithFormat:@"rtsp://192.72.1.1%@", DEFAULT_RTSP_URL_V1];
    }else if (rtsp == 3) {
        liveUrlString = [NSString stringWithFormat:@"rtsp://192.72.1.1%@", DEFAULT_RTSP_URL_AV2];
    }else if (rtsp == 4) {
        liveUrlString = [NSString stringWithFormat:@"rtsp://192.72.1.1%@", DEFAULT_RTSP_URL_AV4];
    }else {
        liveUrlString = [NSString stringWithFormat:@"http://192.72.1.1%@", DEFAULT_MJPEG_PUSH_URL];
    }
    
    if (liveUrlString) {
        
        NSString *cameraTypeInfo = dict[@"Camera.Preview.Source.1.Camid"];
        NSURL *url = [NSURL URLWithString:liveUrlString];
        successCommandHandler(@{cameraTypeInfo:url});
        
    }else{
        
        failureCommandHandler(-1);
    }
}

- (NSDictionary*) buildResultDictionary:(NSString*)result{
    
    NSMutableArray *keyArray;
    NSMutableArray *valArray;
    NSArray *lines;
    
    keyArray = [[NSMutableArray alloc] init];
    valArray = [[NSMutableArray alloc] init];
    lines = [result componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *state = [line componentsSeparatedByString:@"="];
        if ([state count] != 2)
            continue;
        [keyArray addObject:[[state objectAtIndex:0] copy]];
        [valArray addObject:[[state objectAtIndex:1] copy]];
    }
    if ([keyArray count] == 0)
        return nil;
    return [NSDictionary dictionaryWithObjects:valArray forKeys:keyArray];
}

@end
