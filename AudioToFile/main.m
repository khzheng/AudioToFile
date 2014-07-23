//
//  main.m
//  AudioToFile
//
//  Created by Ken Zheng on 7/23/14.
//  Copyright (c) 2014 Toktumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define sineFrequency 880.0

#pragma mark - User-data struct

#pragma mark - Callbacks

#pragma mark - Utility

static char *StringFromOSStatusError(OSStatus error, char *str) {
    bzero(str, sizeof(str));
    
    // see if it appears to be a 4-char-code, look in AudioFile.h for mapping
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else {
        // Nope, format it as integer
        sprintf(str, "%d", (int)error);
    }
    return str;
}

void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    
    char str[20];
    char *errorStr = StringFromOSStatusError(error, str);
    fprintf(stderr, "AudioServicesError: %s (%s)", operation, errorStr);
    
    [NSException raise:@"NSInternalInconsistencyException" format:@"AudioServicesError: %s (%i: %s)\n backtrace:\n %@", operation, (int)error, errorStr, [NSThread callStackSymbols]];
}

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // setup output unit and callback
        // start playing
        // clean up
        
    }
    return 0;
}

