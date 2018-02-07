//
// Copyright 2015 Anton Tananaev (anton.tananaev@gmail.com)
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

// inspiration from https://github.com/voyage11/Location/blob/master/Location/LocationTracker.m
// http://mobileoop.com/background-location-update-programming-for-ios-7
// http://www.creativeworkline.com/2014/12/core-location-manager-ios-8-fetching-location-background/


#import "TCPositionProvider.h"
#import <CoreLocation/CoreLocation.h>
#import "TCDatabaseHelper.h"

@interface TCPositionProvider () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, readonly) double batteryLevel;

@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, assign) long period;
@property (nonatomic, assign) BOOL isEmergencyMode;

@property (nonatomic, strong)NSMutableArray* bgTaskIdList;
@property (assign) UIBackgroundTaskIdentifier masterTaskId;
@property (assign) NSTimer *timer;
@property (nonatomic, strong) NSTimer* delay3Seconds;
@property (nonatomic, assign) BOOL isMonitoringLocation;

@end

@implementation TCPositionProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        self.locationManager.pausesLocationUpdatesAutomatically = YES;
        self.locationManager.activityType = CLActivityTypeFitness;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.distanceFilter = kCLDistanceFilterNone;

        if ([self.locationManager respondsToSelector:@selector(allowsBackgroundLocationUpdates)]) {
            self.locationManager.allowsBackgroundLocationUpdates = YES;
        }

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        self.email = [userDefaults stringForKey:@"email_preference"];
        self.token = [userDefaults stringForKey:@"token_preference"];
        self.period = [userDefaults integerForKey:@"frequency_preference"];
        self.isEmergencyMode = [userDefaults boolForKey:@"emergency_status"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        self.isMonitoringLocation = NO;
    }
    return self;
}

- (void)startUpdates {
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
    }
   [self.locationManager startUpdatingLocation];
    self.isMonitoringLocation = YES;
}

- (void)stopUpdates {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    [self.locationManager stopUpdatingLocation];
    self.isMonitoringLocation = NO;
}



-(void)applicationEnterBackground{
    NSLog(@"applicationEnterBackground");
    // don't do anything if it is emergency mode, just keep the location updates going
    if (self.isEmergencyMode) {
        return;
    }
    if (self.isMonitoringLocation) {
        //Use the BackgroundTaskManager to manage all the background Task
        [self beginNewBackgroundTask];
    }
    
}

- (void) restartLocationUpdates
{
    NSLog(@"restartLocationUpdates");
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    CLLocationManager *locationManager = self.locationManager;
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [locationManager requestAlwaysAuthorization];
    }
    
    [locationManager stopMonitoringSignificantLocationChanges];
    [locationManager startUpdatingLocation];
}




-(UIBackgroundTaskIdentifier)beginNewBackgroundTask
{
    UIApplication* application = [UIApplication sharedApplication];
    
    __block UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
    if([application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]){
        bgTaskId = [application beginBackgroundTaskWithExpirationHandler:^{
            NSLog(@"background task %lu expired", (unsigned long)bgTaskId);
            
            [self.bgTaskIdList removeObject:@(bgTaskId)];
            [application endBackgroundTask:bgTaskId];
            bgTaskId = UIBackgroundTaskInvalid;
            
        }];
        if ( self.masterTaskId == UIBackgroundTaskInvalid )
        {
            self.masterTaskId = bgTaskId;
            NSLog(@"started master task %lu", (unsigned long)self.masterTaskId);
        }
        else
        {
            //add this id to our list
            NSLog(@"started background task %lu", (unsigned long)bgTaskId);
            [self.bgTaskIdList addObject:@(bgTaskId)];
            [self endBackgroundTasks];
        }
    }
    
    return bgTaskId;
}

-(void)endBackgroundTasks
{
    [self drainBGTaskList:NO];
}

-(void)drainBGTaskList:(BOOL)all
{
    //mark end of each of our background task
    UIApplication* application = [UIApplication sharedApplication];
    if([application respondsToSelector:@selector(endBackgroundTask:)]){
        NSUInteger count=self.bgTaskIdList.count;
        for ( NSUInteger i=(all?0:1); i<count; i++ )
        {
            UIBackgroundTaskIdentifier bgTaskId = [[self.bgTaskIdList objectAtIndex:0] integerValue];
            NSLog(@"ending background task with id -%lu", (unsigned long)bgTaskId);
            [application endBackgroundTask:bgTaskId];
            [self.bgTaskIdList removeObjectAtIndex:0];
        }
        if ( self.bgTaskIdList.count > 0 )
        {
            NSLog(@"kept background task id %@", [self.bgTaskIdList objectAtIndex:0]);
        }
        if ( all )
        {
            NSLog(@"no more background tasks running");
            [application endBackgroundTask:self.masterTaskId];
            self.masterTaskId = UIBackgroundTaskInvalid;
        }
        else
        {
            NSLog(@"kept master background task id %lu", (unsigned long)self.masterTaskId);
        }
    }
}










- (double)getBatteryLevel {
    UIDevice *device = [UIDevice currentDevice];
    return device.batteryLevel * 100;
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    
    CLLocation *location = [locations lastObject];
    
    // stop from sending more than twice per period, just to cut down on dupes being sent
    // unless it is emergency mode, then send everything
    if ((!self.lastLocation || [location.timestamp timeIntervalSinceDate:self.lastLocation.timestamp] >= (self.period / 2)) || self.isEmergencyMode) {
        NSLog(@"sending location");
        TCPosition *position = [[TCPosition alloc] initWithManagedObjectContext:[TCDatabaseHelper managedObjectContext]];
        position.email = self.email;
        position.token = self.token;
        position.location = location;
        position.battery = self.batteryLevel;
        position.emergency = self.isEmergencyMode;
        
        
        [self.delegate didUpdatePosition:position];
        self.lastLocation = location;
    }
    
    //If the timer still valid, return it (Will not run the code below)
    // or if it is emergency mode, just keep it running.
    if (self.timer || self.isEmergencyMode) {
        return;
    }
    
    [self beginNewBackgroundTask];
    
    //Restart the locationMaanger after frequency minutes
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.period target:self
                                                           selector:@selector(restartLocationUpdates)
                                                           userInfo:nil
                                                            repeats:NO];
    
    //Will only stop the locationManager after 3 seconds, so that we can get some accurate locations
    //The location manager will only operate for 3 seconds to save battery
    if (self.delay3Seconds) {
        [self.delay3Seconds invalidate];
        //self.delay3Seconds = nil;
    }
    
    self.delay3Seconds = [NSTimer scheduledTimerWithTimeInterval:3 target:self
                                                                    selector:@selector(stopLocationDelayBy3Seconds)
                                                                    userInfo:nil
                                                                     repeats:NO];
}

//Stop the locationManager
-(void)stopLocationDelayBy3Seconds{
    CLLocationManager *locationManager = self.locationManager;
    [locationManager stopUpdatingLocation];
    
    if (self.isMonitoringLocation) {
        locationManager.distanceFilter = 500;
        [locationManager startMonitoringSignificantLocationChanges];
    }
    
    NSLog(@"locationManager stop Updating after 3 seconds");
}

- (void)applicationWillEnterForeground
{
    NSLog(@"entering foreground");
    // don't do anything if it is emergency mode, we have kept it running.
    if (self.isEmergencyMode) {
        return;
    }
    
    if (self.isMonitoringLocation) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
        [self startUpdates];
    }
    
}

@end
