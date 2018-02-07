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

#import "TCProtocolFormatter.h"

@implementation TCProtocolFormatter

+ (NSURL *)formatPostion:(TCPosition *)position address:(NSString *)address port:(long)port path:(NSString *)path {
    
    NSURLComponents *components = [[NSURLComponents alloc] init];
    
    components.scheme = @"https";
    components.percentEncodedHost = [NSString stringWithFormat:@"%@:%ld", address, port];
    components.path = [NSString stringWithFormat:@"%@", path];
    
    NSMutableString *query = [[NSMutableString alloc] init];
    [query appendFormat:@"email=%@&", position.email];
    [query appendFormat:@"token=%@&", position.token];
    [query appendFormat:@"latitude=%.06f&", position.latitude];
    [query appendFormat:@"longitude=%.06f&", position.longitude];
    [query appendFormat:@"speed=%g&", position.speed];
    [query appendFormat:@"bearing=%g&", position.course];
    [query appendFormat:@"altitude=%g&", position.altitude];
    [query appendFormat:@"battery=%g&", position.battery];
    [query appendFormat:@"emergency=%g", position.emergency];
    components.query = query; // use queryItems for iOS 8
    
    return components.URL;
}

@end
