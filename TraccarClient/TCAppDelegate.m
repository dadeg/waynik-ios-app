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

#import "TCAppDelegate.h"

#import "TCRequestManager.h"
#import "IASKSettingsReader.h" // for the event kIASKAppSettingChanged

// Getting all this firebase stuff from https://github.com/firebase/quickstart-ios/blob/master/messaging/MessagingExample/AppDelegate.m#L101-L130
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif
@import Firebase;
@import FirebaseInstanceID;
@import FirebaseMessaging;


// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface TCAppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end
#endif

// Copied from Apple's header in case it is missing in some cases (e.g. pre-Xcode 8 builds).
#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@implementation TCAppDelegate

NSString *const kGCMMessageIDKey = @"gcm.message_id";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Initialize other defaults
    [self registerDefaultsFromSettingsBundle];

    // Firebase stuff
    [self setupFirebase];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {

    // Change service status
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:NO forKey:@"service_status_preference"];
    [userDefaults setValue:NO forKey:@"emergency_status"];
    
    [self saveContext];
}

- (void)registerDefaultsFromSettingsBundle {

    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"InAppSettings" ofType:@"bundle"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if(key && [[prefSpecification allKeys] containsObject:@"DefaultValue"]) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
    
}

- (BOOL)setupFirebase {
    
    // Register for remote notifications. This shows a permission dialog on first run, to
    // show the dialog at a more appropriate time move this registration accordingly.
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        UIUserNotificationType allNotificationTypes =
        (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    } else {
        // iOS 10 or later
        #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        // For iOS 10 display notification (sent via APNS)
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions =
        UNAuthorizationOptionAlert
        | UNAuthorizationOptionSound
        | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {
        }];
        
        // For iOS 10 data message (sent via FCM)
        [FIRMessaging messaging].remoteMessageDelegate = self;
        #endif
    }
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    
    // [START configure_firebase]
    [FIRApp configure];
    // [END configure_firebase]
    // [START add_token_refresh_observer]
    // Add observer for InstanceID token refresh callback.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:kFIRInstanceIDTokenRefreshNotification object:nil];
    // [END add_token_refresh_observer]
    
    // send the token every time the app is started.
    // I am not sure when, if ever, the tokenRefreshNotification observer fires.
    // But on install, the user's email and password are not set up
    // so the token cannot be sent to the server at that time.
    // only once we have the login info will we be able to register the device.
    // therefore we send it upon boot up, just in case for launches in which the user data is already filled out
    [self sendFCMRegistrationTokenToServer];
    
    // and observe the user settings to send it again when they change.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChangedNotification:)
        name:kIASKAppSettingChanged object:nil];
    
    return YES;
}


// [START receive_message]
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.
    // TODO: Handle data of notification
    
    // Print message ID.
    if (userInfo[kGCMMessageIDKey]) {
        NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    }
    
    [self handleIncomingDataMessage: userInfo];
    
    // Print full message.
    NSLog(@"didReceiveRemoteNotification: %@", userInfo);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // If you are receiving a notification message while your app is in the background,
    // this callback will not be fired till the user taps on the notification launching the application.
    // TODO: Handle data of notification
    
    // Print message ID.
    if (userInfo[kGCMMessageIDKey]) {
        NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    }
    
    [self handleIncomingDataMessage:userInfo];
    
    // Print full message.
    NSLog(@"didReceiveRemoteNotification fetchCompletionHandler: %@", userInfo);
    
    completionHandler(UIBackgroundFetchResultNewData);
}
// [END receive_message]

// [START ios_10_message_handling]
// Receive displayed notifications for iOS 10 devices.
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Handle incoming notification messages while app is in the foreground.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    // Print message ID.
    NSDictionary *userInfo = notification.request.content.userInfo;
    if (userInfo[kGCMMessageIDKey]) {
        NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    }
    
    [self handleIncomingDataMessage: userInfo];
    
    // Print full message.
    NSLog(@"ios10 willPresentNotification: %@", userInfo);
    
    // Change this to your preferred presentation option
    //UNNotificationPresentationOptionNone means silent.
    completionHandler(UNNotificationPresentationOptionNone);
}

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    if (userInfo[kGCMMessageIDKey]) {
        NSLog(@"Message ID: %@", userInfo[kGCMMessageIDKey]);
    }
    
    [self handleIncomingDataMessage: userInfo];
    
    // Print full message.
    NSLog(@"didReceiveNotificationResponse withCompletionHandler: %@", userInfo);
    
    completionHandler();
}
#endif
// [END ios_10_message_handling]

// [START ios_10_data_message_handling]
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    [self handleIncomingDataMessage: remoteMessage.appData];
    
    NSLog(@"applicationReceivedRemoteMessage: %@", remoteMessage.appData);
}
#endif
// [END ios_10_data_message_handling]

// [START refresh_token]
- (void)tokenRefreshNotification:(NSNotification *)notification {
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    NSString *refreshedToken = [[FIRInstanceID instanceID] token];
    NSLog(@"InstanceID token: %@", refreshedToken);
    
    // Connect to FCM since connection may have failed when attempted before having a token.
    [self connectToFcm];
    
    // TODO: If necessary send token to application server.
    [self sendFCMRegistrationTokenToServer];
    
}
// [END refresh_token]

- (void)settingsChangedNotification:(NSNotification *)notification {
    [self sendFCMRegistrationTokenToServer];
}

- (void)sendFCMRegistrationTokenToServer {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    
    components.scheme = @"https";
    components.percentEncodedHost = [NSString stringWithFormat:@"%@:%d", @"prgd6brc2f.execute-api.us-west-2.amazonaws.com", 443];
    components.path = @"/production/notifications/register";
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *email = [userDefaults stringForKey:@"email_preference"];
    NSString *securityToken = [userDefaults stringForKey:@"token_preference"];
    
    NSMutableString *query = [[NSMutableString alloc] init];
    [query appendFormat:@"email=%@&", email];
    [query appendFormat:@"security_token=%@&", securityToken];
    [query appendFormat:@"device_token=%@", [[FIRInstanceID instanceID] token]];
    components.query = query; // use queryItems for iOS 8

    [TCRequestManager sendRequest:components.URL completionHandler:^(BOOL success) {
        NSLog(@"sent registration token, %@, for FCM, success: %d", [[FIRInstanceID instanceID] token], success);
    }];
}

- (void)handleIncomingDataMessage:(NSDictionary *) messageData {
    // set the frequency if needed. Turn the service on if needed. turn on/off emergency
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL emergencytoggled = NO;
    
    if (messageData[@"frequency"] != nil) {
        [userDefaults setValue:messageData[@"frequency"] forKey:@"frequency_preference"];
    }
    
    if (messageData[@"emergency"] != nil) {
        emergencytoggled = YES;
        [userDefaults setBool:[messageData[@"emergency"] boolValue] forKey:@"emergency_status"];
    }
    
    if (!emergencytoggled) {
        // always turn it on at the end unless emergency since it handles it separately.
        // do not restart if emergency was activated.
        [userDefaults setBool:NO forKey:@"service_status_preference"];
        [userDefaults setBool:YES forKey:@"service_status_preference"];
    }
}

// [START connect_to_fcm]
- (void)connectToFcm {
    // Won't connect since there is no token
    if (![[FIRInstanceID instanceID] token]) {
        return;
    }
    
    // Disconnect previous FCM connection if it exists.
    [[FIRMessaging messaging] disconnect];
    
    [[FIRMessaging messaging] connectWithCompletion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Unable to connect to FCM. %@", error);
        } else {
            NSLog(@"Connected to FCM.");
        }
    }];
}
// [END connect_to_fcm]

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Unable to register for remote notifications: %@", error);
}

// This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
// If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
// the InstanceID token.
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"APNs token retrieved: %@", deviceToken);
    
    // With swizzling disabled you must set the APNs token here.
    // [[FIRInstanceID instanceID] setAPNSToken:deviceToken type:FIRInstanceIDAPNSTokenTypeSandbox];
}

// [START connect_on_active]
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self connectToFcm];
}
// [END connect_on_active]

// [START disconnect_from_fcm]
- (void)applicationDidEnterBackground:(UIApplication *)application {
    // why would we want to disconnect?
    [[FIRMessaging messaging] disconnect];
    NSLog(@"Disconnected from FCM");
}
// [END disconnect_from_fcm]

#pragma mark - Core Data

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"TraccarClient" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"TraccarClient.sqlite"];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:nil]) {
        NSLog(@"Error in persistentStoreCoordinator");
    }
    
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:nil]) {
            NSLog(@"Error in saveContext");
        }
    }
}

@end
