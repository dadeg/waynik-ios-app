//
// Copyright 2013 - 2015 Anton Tananaev (anton.tananaev@gmail.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TCMainViewController.h"
#import "TCStatusViewController.h"
#import "TCTrackingController.h"

@interface TCMainViewController ()

@property (nonatomic, strong) TCTrackingController *trackingController;
@property (nonatomic) BOOL isServiceRunning;
@property (nonatomic) BOOL isEmergencyMode;

- (void)defaultsChanged:(NSNotification *)notification;

@end

@implementation TCMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedString(@"Waynik Transmitter", @"");
    self.showCreditsFooter = NO;
    self.neverShowPrivacySettings = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification
                 object:nil];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self];
}

- (void)defaultsChanged:(NSNotification *)notification
{
    NSUserDefaults *defaults = (NSUserDefaults *)[notification object];
    
    BOOL emergencyStatus = [defaults boolForKey:@"emergency_status"];
    if (emergencyStatus && !self.isEmergencyMode) {
        // time to turn the emergency mode on.
        self.isEmergencyMode = YES;
        [TCStatusViewController addMessage:NSLocalizedString(@"Emergency mode activated", @"")];
        // we need a new service started to inject the new emergency mode.
        if (!self.isServiceRunning) {
            // this will automatically switch the status to "on" and start the service
            [defaults setBool:YES forKey:@"service_status_preference"];
        } else {
            // restart the service because it is already running and we need new values initialized
            [self restartService];
        }
        
        //[self makeEmergencyPhoneCall];
    } else if (!emergencyStatus && self.isEmergencyMode) {
        // time to turn the emergency mode off.
        self.isEmergencyMode = NO;
        [TCStatusViewController addMessage:NSLocalizedString(@"Emergency mode deactivated", @"")];
        // must restart the service if it is currently running because we need to reinitialize nonemergencymode.
        if (self.isServiceRunning) {
            [self restartService];
        }
    }
    
    BOOL status = [defaults boolForKey:@"service_status_preference"];
    if (status && !self.isServiceRunning) {
        [self startService];
    } else if (!status && self.isServiceRunning) {
        [self stopService];
        if (self.isEmergencyMode) {
            // turn off emergency mode, too.
            // this will automatically switch emergency to "off" and do cleanup
            [defaults setBool:NO forKey:@"emergency_status"];
        }
    }
}

- (void)startService
{
    [TCStatusViewController addMessage:NSLocalizedString(@"Service created", @"")];
    self.trackingController = [[TCTrackingController alloc] init];
    [self.trackingController start];
    self.isServiceRunning = YES;
}

- (void)stopService
{
    [TCStatusViewController addMessage:NSLocalizedString(@"Service destroyed", @"")];
    [self.trackingController stop];
    self.trackingController = nil;
    self.isServiceRunning = NO;
}

- (void)restartService
{
    [self stopService];
    [self startService];
}

- (void)makeEmergencyPhoneCall
{
    UIApplication *myApp = [UIApplication sharedApplication];
    NSString *theCall = [NSString stringWithFormat:@"tel:12026431047"];
    NSLog(@"making call with %@",theCall);
    [myApp openURL:[NSURL URLWithString:theCall]];
}

@end
