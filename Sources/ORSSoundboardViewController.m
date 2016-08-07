//
//  ORSSoundboardViewController.m
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import "ORSSoundboardViewController.h"

#import <MIKMIDI/MIKMIDI.h>
#import <MIKMIDI/MIKMIDIPlayer.h>
#import <MIKMIDI/MIKMIDISequencer.h>

@interface ORSSoundboardViewController ()

@property (nonatomic, strong) MIKMIDIDeviceManager *deviceManager;
@property (nonatomic, strong) MIKMIDIDevice	*device;
@property (nonatomic, strong) id connectionToken;
@property (nonatomic, strong) MIKMIDISequencer *sequencer;

@property (nonatomic, strong) MIKMIDISequence *sequence;

@property (nonatomic, getter=isPlaying, readonly) BOOL playing;
@property (nonatomic, getter=isRecording, readonly) BOOL recording;

//@property (weak) IBOutlet MIKMIDISequenceView *trackView;
@property (nonatomic, readonly) NSString *recordButtonLabel;
@property (nonatomic, readonly) NSString *playButtonLabel;

@property (nonatomic, strong, readonly) MIKMIDISynthesizer *synthesizer;

@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *pianoButtons;

@end

@implementation ORSSoundboardViewController
- (IBAction)sendOff:(id)sender {
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"file"] URLByAppendingPathComponent:@"mid"];
    [self.sequence writeToURL:fileURL error:NULL];
    NSLog(@"file written");
    
    NSData *midiFile = [[NSData alloc] initWithContentsOfFile:[fileURL path]];
    NSString *urlString = @"https://64.173.45.245:3000/midi_input";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"userfile\"; filename=\"AudioFile3.m4a\"\r\n"]] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData:midiFile]];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError){
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains
        (NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *randomStr = [[NSProcessInfo processInfo] globallyUniqueString];
        //make a file name to write the data to using the documents directory:
        NSString *fileName = [NSString stringWithFormat:@"%@/%@.mp3",
                              documentsDirectory, randomStr];
        //create content - four lines of text
        
        //save content to the documents directory
        [data writeToFile:fileName atomically: YES];
        

        
        //[data writeToURL:[NSURL fileURLWithPath:NSDocumentDirectory atomically:YES];
        NSLog(@"Async Request Completed");
        
    }];
    
   
    NSLog(@"Sent Async Request");
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Building your tune" message:@"You'll receive a notification when your tune is complete." preferredStyle: UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
    //NSLog(@"Return String= %@",returnString);
}
- (IBAction)record:(id)sender {
    NSLog(@"Record Clicked");
    
    if (self.isRecording) {
        NSLog(@"Stopping Recording");
        [sender setBackgroundColor: [UIColor grayColor]];
        [self.sequencer stop];
        
        //[self.trackView setNeedsDisplay:YES];
        return;
    } else {
        NSLog(@"Recording");
        [sender setBackgroundColor: [UIColor redColor]];
        
        if (!self.sequence) self.sequence = [MIKMIDISequence sequence];
        NSError *error = nil;
        MIKMIDITrack *newTrack = [self.sequence addTrackWithError:&error];
        if (!newTrack) {
            NSLog(@"Error");
            //[self presentError:error];
            return;
        }
        
        self.sequencer.recordEnabledTracks =[NSSet setWithObject:newTrack];
        [self.sequencer setCommandScheduler:self.synthesizer forTrack: newTrack ];
        [self.sequencer startRecording];
    }
    
}

- (IBAction)play:(id)sender {
    NSLog(@"Play Clicked");
    self.sequencer.createSynthsIfNeeded = true;
    self.isPlaying ? [self.sequencer stop] : [self.sequencer startPlayback];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    self.sequence = [MIKMIDISequence sequence];
    self.sequencer = [MIKMIDISequencer sequencer];
    self.sequencer = [MIKMIDISequencer sequencerWithSequence:self.sequence];
    self.sequencer.preRoll = 0;
    self.sequencer.clickTrackStatus = MIKMIDISequencerClickTrackStatusDisabled;
    
	for (UIButton *button in self.pianoButtons) {
		[button addTarget:self action:@selector(pianoKeyDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(pianoKeyDown:) forControlEvents:UIControlEventTouchDragEnter];
		[button addTarget:self action:@selector(pianoKeyUp:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(pianoKeyUp:) forControlEvents:UIControlEventTouchDragExit];
		[button addTarget:self action:@selector(pianoKeyUp:) forControlEvents:UIControlEventTouchUpOutside];
		[button addTarget:self action:@selector(pianoKeyUp:) forControlEvents:UIControlEventTouchCancel];
	}
}

#pragma mark - Actions

- (IBAction)pianoKeyDown:(id)sender
{
    NSLog(@"%d", [sender tag]);
	UInt8 note = 60 + [sender tag];
    
	MIKMIDINoteOnCommand *noteOn = [MIKMIDINoteOnCommand noteOnCommandWithNote:note velocity:127 channel:0 timestamp:[NSDate date]];
	[self.synthesizer handleMIDIMessages:@[noteOn]];
    [self.sequencer recordMIDICommand:noteOn];
    
}

- (IBAction)pianoKeyUp:(id)sender
{
	UInt8 note = 60 + [sender tag];
	MIKMIDINoteOffCommand *noteOff = [MIKMIDINoteOffCommand noteOffCommandWithNote:note velocity:127 channel:0 timestamp:[NSDate date]];
	[self.synthesizer handleMIDIMessages:@[noteOff]];
    [self.sequencer recordMIDICommand:noteOff];
    
}

#pragma mark - Private

- (void)disconnectFromDevice:(MIKMIDIDevice *)device
{
	if (!device) return;
	[self.deviceManager disconnectConnectionForToken:self.connectionToken];
	
	self.textView.text = @"";
}

- (void)connectToDevice:(MIKMIDIDevice *)device
{
	if (!device) return;
	NSArray *sources = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
	if (![sources count]) return;
	MIKMIDISourceEndpoint *source = [sources objectAtIndex:0];
	NSError *error = nil;
	
	id connectionToken = [self.deviceManager connectInput:source error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
		
		NSMutableString *textViewString = [self.textView.text mutableCopy];
		for (MIKMIDIChannelVoiceCommand *command in commands) {
			if ((command.commandType | 0x0F) == MIKMIDICommandTypeSystemMessage) continue;
			
			[[UIApplication sharedApplication] handleMIDICommand:command];
			
			[textViewString appendFormat:@"Received: %@\n", command];
			NSLog(@"Received: %@", command);
		}
		self.textView.text = textViewString;
	}];
	if (!connectionToken) NSLog(@"Unable to connect to input: %@", error);
	self.connectionToken = connectionToken;
}

#pragma mark ORSAvailableDevicesTableViewControllerDelegate

- (void)availableDevicesTableViewController:(ORSAvailableDevicesTableViewController *)controller midiDeviceWasSelected:(MIKMIDIDevice *)device
{
	self.device = device;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"availableDevices"]) {
		if (![self.deviceManager.availableDevices containsObject:self.device]) {
			self.device = nil;
		}
	}
}

#pragma mark - Properties

@synthesize deviceManager = _deviceManager;

- (void)setDeviceManager:(MIKMIDIDeviceManager *)deviceManager
{
	if (deviceManager != _deviceManager) {
		[_deviceManager removeObserver:self forKeyPath:@"availableDevices"];
		_deviceManager = deviceManager;
		[_deviceManager addObserver:self forKeyPath:@"availableDevices" options:NSKeyValueObservingOptionInitial context:NULL];
	}
}

- (MIKMIDIDeviceManager *)deviceManager
{
	if (!_deviceManager) {
		self.deviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
	}
	return _deviceManager;
}

- (void)setDevice:(MIKMIDIDevice *)device
{
	if (device != _device) {
		[self disconnectFromDevice:_device];
		_device = device;
		[self connectToDevice:_device];
	}
}

@synthesize synthesizer = _synthesizer;
- (MIKMIDISynthesizer *)synthesizer
{
	if (!_synthesizer) {
		_synthesizer = [[MIKMIDISynthesizer alloc] init];
		NSURL *soundfont = [[NSBundle mainBundle] URLForResource:@"Grand Piano" withExtension:@"sf2"];
		NSError *error = nil;
		if (![_synthesizer loadSoundfontFromFileAtURL:soundfont error:&error]) {
			NSLog(@"Error loading soundfont for synthesizer. Sound will be degraded. %@", error);
		}
	}
	return _synthesizer;
}

+ (NSSet *)keyPathsForValuesAffectingPlaying
{
    return [NSSet setWithObjects:@"sequencer.playing", nil];
}

- (BOOL)isPlaying
{
    return self.sequencer.isPlaying;
}

+ (NSSet *)keyPathsForValuesAffectingRecording
{
    return [NSSet setWithObjects:@"sequencer.recording", nil];
}

- (BOOL)isRecording
{
    return self.sequencer.isRecording;
}

+ (NSSet *)keyPathsForValuesAffectingRecordButtonLabel
{
    return [NSSet setWithObjects:@"recording", nil];
}

- (NSString *)recordButtonLabel
{
    return self.isRecording ? @"Stop" : @"Record";
}

+ (NSSet *)keyPathsForValuesAffectingPlayButtonLabel
{
    return [NSSet setWithObjects:@"playing", nil];
}

- (NSString *)playButtonLabel
{
    return self.isPlaying ? @"Stop" : @"Play";
}

@end
