//
//  DummySignInService.h
//  FirstProject-Objc
//
//  Created by xjshi on 17/01/2017.
//  Copyright © 2017 sxj. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^SignInResponse)(BOOL);

@interface DummySignInService : NSObject

- (void)signInWithUsername:(NSString *)username password:(NSString *)password complete:(SignInResponse)completeBlock;

@end
