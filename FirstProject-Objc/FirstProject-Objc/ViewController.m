//
//  ViewController.m
//  FirstProject-Objc
//
//  Created by xjshi on 17/01/2017.
//  Copyright © 2017 sxj. All rights reserved.
//

#import "ViewController.h"
#import "DummySignInService.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIButton *signinButton;
@property (weak, nonatomic) IBOutlet UILabel *signinFailureText;

@property (strong, nonatomic) DummySignInService *signinService;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.signinService = [DummySignInService new];
    /*
    [[self.usernameTextField.rac_textSignal filter:^BOOL(id value) {
        NSString *text = value;
        return text.length > 3;
    }] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
     */
    /*
    [[[self.usernameTextField.rac_textSignal map:^id(NSString *text) {
        return @(text.length);
    }] filter:^BOOL(NSNumber *length) {
        return length.integerValue > 3;
    }] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
     */
    
    RACSignal *validUsernameSignal = [self.usernameTextField.rac_textSignal map:^id(NSString *text) {
        return @([self isValidUsername:text]);
    }];
    RACSignal *validPasswordSignal = [self.passwordTextField.rac_textSignal map:^id(NSString *text) {
        return @([self isValidPassword:text]);
    }];
    
    /*
    [[validPasswordSignal map:^id(NSNumber *passwordValid) {
        return passwordValid.boolValue ? [UIColor clearColor] : [UIColor yellowColor];
    }] subscribeNext:^(UIColor *color) {
        self.passwordTextField.backgroundColor = color;
    }];
     */
    
    RAC(self.passwordTextField, backgroundColor) = [validPasswordSignal map:^id(NSNumber *passwordValid) {
        return [passwordValid boolValue] ? [UIColor clearColor] : [UIColor yellowColor];
    }];
    RAC(self.usernameTextField, backgroundColor) = [validUsernameSignal map:^id(NSNumber *usernameValid) {
        return [usernameValid boolValue] ? [UIColor clearColor] : [UIColor yellowColor];
    }];
    
    RACSignal *signupActiveSignal = [RACSignal combineLatest:@[validUsernameSignal, validPasswordSignal]
                                                      reduce:^id(NSNumber *usernameValid, NSNumber *passwordValid){
                                                          return @(usernameValid.boolValue && passwordValid.boolValue);
                                                      }];
    [signupActiveSignal subscribeNext:^(NSNumber *signupActive) {
        self.signinButton.enabled = signupActive.boolValue;
    }];
    
    //按钮
    /*
    [[self.signinButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        NSLog(@"%@", x);
    }];
    */
    /*  1. The rac_signalForControlEvents emits a next event (with the source UIButton as its event data) when you tap the button.
           The map step creates and returns the sign-in signal, which means the following pipeline steps now receive a RACSignal.
        2. 信号的信号，外层信号可以在subscribeNext块中订阅内层信号.
        3. result in a nested mess!
     */
//    [[[self.signinButton rac_signalForControlEvents:UIControlEventTouchUpInside] map:^id(id value) {
//        return [self signInSignal];
//    }] subscribeNext:^(id x) {
//        NSLog(@"1.登录结果： %@", x);
//    }];
    
    [[[[self.signinButton rac_signalForControlEvents:UIControlEventTouchUpInside] doNext:^(id x) {
        self.signinFailureText.hidden = YES;
        self.signinButton.enabled = NO;
    }] flattenMap:^RACStream *(id value) {
        return [self signInSignal];
    }] subscribeNext:^(NSNumber *success) {
        NSLog(@"2.登录结果： %@", success);
        self.signinButton.enabled = YES;
        BOOL tmp = success.boolValue;
        self.signinFailureText.hidden = tmp;
        if (tmp) {
            [self performSegueWithIdentifier:@"signInSuccess" sender:self];
        }
    }];

}

- (RACSignal *)signInSignal {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [self.signinService signInWithUsername:self.usernameTextField.text password:self.passwordTextField.text complete:^(BOOL success) {
            [subscriber sendNext:@(success)];
            [subscriber sendCompleted];
        }];
        return nil;
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)isValidUsername:(NSString *)username {
    return username.length > 3;
}

- (BOOL)isValidPassword:(NSString *)password {
    return password.length > 3;
}


@end
