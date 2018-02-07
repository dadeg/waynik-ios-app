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
#import "TCDatabaseHelper.h"

@interface TCDatabaseHelperTests : TCCoreDataTests

@end

@implementation TCDatabaseHelperTests

- (void)testFormatPosition {

    TCDatabaseHelper *databaseHelper = [[TCDatabaseHelper alloc] initWithManagedObjectContext:self.managedObjectContext];
    
    XCTAssertNil([databaseHelper selectPosition]);
    
    TCPosition *position = [[TCPosition alloc] initWithManagedObjectContext:self.managedObjectContext];
    position.email = @"123456789012345";
    
    XCTAssertNotNil([databaseHelper selectPosition]);
    
    [databaseHelper deletePosition:position];
    
    XCTAssertNil([databaseHelper selectPosition]);
}

@end
