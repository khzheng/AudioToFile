//
//  main.m
//  AudioToFile
//
//  Created by Ken Zheng on 7/23/14.
//  Copyright (c) 2014 Toktumi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define SAVE
#define sineFrequency 880.0

#pragma mark - User-data struct

typedef struct MySineWavePlayer {
    AudioUnit outputUnit;
    double startingFrameCount;
    AudioStreamBasicDescription outputFormat;
} MySineWavePlayer;

#pragma mark - Callbacks

OSStatus SineWaveRenderProc(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData) {
//    printf("needs %d frames at %f\n", inNumberFrames, CFAbsoluteTimeGetCurrent());
    
    MySineWavePlayer *player = (MySineWavePlayer *)inRefCon;
    
    double j = player->startingFrameCount;
    double cycleLength = 44100. / sineFrequency;
    int frame = 0;
    for (frame = 0; frame < inNumberFrames; frame++) {
        Float32 *data = (Float32 *)ioData->mBuffers[0].mData;
        data[frame] = (Float32)sin(2 * M_PI * (j / cycleLength));
        
        // copy to right channel too
        data = (Float32 *)ioData->mBuffers[1].mData;
        data[frame] = (Float32)sin(2 * M_PI * (j / cycleLength));
        
        j += 1.0;
        if (j > cycleLength)
            j -= cycleLength;
    }
    
    player->startingFrameCount = j;
    
    return noErr;
}

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

void CreateAndConnectOutputUnit (MySineWavePlayer *player) {
    // define desc that matches output
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
#ifdef SAVE
    outputcd.componentSubType = kAudioUnitSubType_GenericOutput;
#else
    outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // find the compnent that matches the output desc
    AudioComponent comp = AudioComponentFindNext(NULL, &outputcd);
    if (comp == NULL) {
        printf("coun't get output component");
        exit(-1);
    }
    
    // create the output unit
    CheckError(AudioComponentInstanceNew(comp, &player->outputUnit), "Couldn't create output unit");
    
    // get output stream format
    UInt32 propertySize = sizeof(AudioStreamBasicDescription);
    CheckError(AudioUnitGetProperty(player->outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &player->outputFormat, &propertySize), "Couldn't get output stream format");
    
    // set the render callback for output
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = SineWaveRenderProc;
    callbackStruct.inputProcRefCon = player;
    CheckError(AudioUnitSetProperty(player->outputUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct)), "Couldn't set render callback for output");
    
    // initialize output unit
    CheckError(AudioUnitInitialize(player->outputUnit), "Couldn't initialize output unit");
}

#define IN_NUMBER_FRAMES 64

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        NSMutableData *audioData = [[NSMutableData alloc] init];
        
        MySineWavePlayer player = {0};
        
        // setup output unit and callback
        CreateAndConnectOutputUnit(&player);
        
        // start playing
        CheckError(AudioOutputUnitStart(player.outputUnit), "Couldn't start output unit");
        
#ifdef SAVE
        int count = 0;
        
        while (count < 1000) {
//            if (count % 64 == 0) {
                AudioUnitRenderActionFlags flags = kAudioOfflineUnitRenderAction_Render;
                AudioTimeStamp inTimeStamp;
                memset(&inTimeStamp, 0, sizeof(inTimeStamp));
                inTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
                UInt32 busNumber = 0;
                UInt32 inNumberFrames = IN_NUMBER_FRAMES;
                
                UInt32 numberBuffers = player.outputFormat.mChannelsPerFrame;
                UInt32 bufferListSize = offsetof(AudioBufferList, mBuffers) + (numberBuffers * sizeof(AudioBuffer));
                AudioBufferList *bufferList = malloc(bufferListSize);
                //            UInt32 numberBytes = inNumberFrames * player.outputFormat.mBytesPerFrame;
                bufferList->mNumberBuffers = numberBuffers;
                for (int i = 0; i < numberBuffers; i++) {
                    bufferList->mBuffers[i].mNumberChannels = player.outputFormat.mChannelsPerFrame;
                    bufferList->mBuffers[i].mDataByteSize = inNumberFrames*sizeof(AudioUnitSampleType);
                    bufferList->mBuffers[i].mData = calloc(inNumberFrames, sizeof(AudioUnitSampleType));//malloc(numberBytes);
                }
                
                CheckError(AudioUnitRender(player.outputUnit, &flags, &inTimeStamp, busNumber, inNumberFrames, bufferList), "Couldn't render audio data");
                
                [audioData appendBytes:bufferList->mBuffers[0].mData length:inNumberFrames];
                
                inTimeStamp.mSampleTime += inNumberFrames;
//            }
            count++;
        }
#endif
        // play for 5 seconds
//        sleep(5);
        
//        printf("done sleep");
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];
        NSString *destinationFilePath = [NSString stringWithFormat:@"%@/output", documentsDirectory];
        [audioData writeToFile:destinationFilePath atomically:NO];
        
        [audioData release];
        
    cleanup:
        AudioOutputUnitStop(player.outputUnit);
        AudioUnitUninitialize(player.outputUnit);
        AudioComponentInstanceDispose(player.outputUnit);
        
    }
    return 0;
}

