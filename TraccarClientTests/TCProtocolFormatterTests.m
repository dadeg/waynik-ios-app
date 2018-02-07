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

#import "TCCoreDataTests.h"
#import "TCProtocolFormatter.h"

@interface TCProtocolFormatterTests : TCCoreDataTests

@end

@implementation TCProtocolFormatterTests

- (void)testFormatPosition {
    
    TCPosition *position = [[TCPosition alloc] initWithManagedObjectContext:self.managedObjectContext];
    position.email = @"123456789012345";
    position.token = @"123456789012345";
    
    NSURL *url = [TCProtocolFormatter formatPostion:position address:@"localhost" port:5055 path:@"/"];
    
    XCTAssertEqualObjects(@"http://localhost:5055?email=123456789012345&token=123456789012345&latitude=0.000000&longitude=0.000000&speed=0&bearing=0&altitude=0&battery=0", url.absoluteString);
}

@end
