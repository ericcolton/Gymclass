//
//  CSWLoginViewController.m
//  Gymclass
//
//  Created by ERIC COLTON on 9/20/13.
//  Copyright (c) 2013 Cindy Software. All rights reserved.
//

#import "CSWLoginViewController.h"
#import "CSWMembership.h"
#import "CSWScheduleStore.h"
#import "CSWPrimaryViewController.h"
#import "CSWWorkout.h"
#import "CSWWod.h"
#import "CSWWeek.h"
#import "CSWDayMarker.h"
#import "CSWInstructor.h"
#import "CSWLocation.h"
#import "CSWAppDelegate.h"
#import "Flurry.h"

#define NAV_BAR_HEIGHT 40
#define kAddGymTitle @"Add a new gym..."

@interface CSWLoginViewController ()
{
    UIButton *_blackoutButton;
    UIButton *_escapeTextEntryButton;
    UIBarButtonItem *_flexSpace;
    NSOperationQueue *_backgroundQueue;
    CSWScheduleStore *_store;
}

@property (strong, nonatomic) CSWGymSelector *gymSelector;
@property (strong, nonatomic) UIBarButtonItem *selectGymButton;
@property (strong, nonatomic) UIBarButtonItem *refreshButton;

-(void)configureView;

@end

@implementation CSWLoginViewController

//
#pragma mark init methods (public)
//
-(id)initForcingGymSelection:(bool)aForceSelection;
{
    self = [super init];
    if ( self ) {
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _backgroundQueue = [NSOperationQueue new];
        _store = [CSWScheduleStore sharedStore];
    }
    return self;
}

//
#pragma mark superclass methods
//
- (void)viewDidLoad
{
    [super viewDidLoad];

    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshPressed:)];
    self.refreshButton.tintColor = [UIColor whiteColor];
    self.selectGymButton = [[UIBarButtonItem alloc] initWithTitle:@"Select Gym" style:UIBarButtonItemStyleBordered target:self action:@selector(selectGymPressed:)];
    self.selectGymButton.tintColor = [UIColor whiteColor];
    
    self.emailTextField.delegate = self;
    self.passwordTextField.delegate = self;
    
    _flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    //
    // Warn user that we are using DEV backend
    //
    self.devWarningLabel.text = ( DEV_BACKEND_MODE ) ? @"DEV" : @"";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    _gymSelector = nil;
    _flexSpace = nil;
    _refreshButton = nil;
    _selectGymButton = nil;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateButtonStatuses];

    self.navigationController.navigationBarHidden = TRUE;
    
    [self configureView];
}

-(void)viewDidAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:FALSE animated:TRUE];
    [self setToolbarItems:@[self.refreshButton, _flexSpace, self.selectGymButton] animated:TRUE];
    
    if ( ![CSWMembership sharedMembership].gymId ) {

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self selectGymPressed:nil];
        }];
    }
}

//
#pragma mark accessor methods (private)
//
-(CSWGymSelector *)gymSelector
{
    if ( !_gymSelector ) {
        
        _gymSelector = [[CSWGymSelector alloc] init];
        _gymSelector.delegate = self;
        _gymSelector.networkIndicator = self.networkActivity;
        
        NSString *gymId = [CSWMembership sharedMembership].gymId;
        if ( gymId ) {
            _gymSelector.selectedGymId = gymId;
        }
    }

    return _gymSelector;
}


//
#pragma mark instance methods (public)
//
-(void)selectGymPressed:(id)sender
{
    if ( !_blackoutButton ) {
        _blackoutButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _blackoutButton.frame = self.view.bounds;
        _blackoutButton.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.5];
        [_blackoutButton addTarget:self action:@selector(dismissGymSelector:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    //may remove nothing
    [_blackoutButton removeTarget:self action:@selector(dismissGymSelector:) forControlEvents:UIControlEventTouchUpInside];

    if ( sender ) {
        [_blackoutButton addTarget:self action:@selector(dismissGymSelector:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    self.selectGymButton.enabled = FALSE;
    
    [self.view addSubview:_blackoutButton];
    
    CGFloat selfViewHeight = self.view.bounds.size.height;
    CGSize gsSize = self.gymSelector.view.frame.size;
    
    self.gymSelector.view.frame = CGRectMake(0, selfViewHeight, gsSize.width, gsSize.height);
    
    [self.gymSelector prepareView];
    [self.view addSubview:self.gymSelector.view];
    
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.gymSelector.view.frame = CGRectMake(0,selfViewHeight-gsSize.height,gsSize.width,gsSize.height);
                         _blackoutButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.75];
                     }
                     completion:nil
     ];
}

-(IBAction)skipPressed:(id)sender
{
    [Flurry logEvent:kLoginSkipped withParameters:@{ @"gymId" : [CSWScheduleStore sharedStore].gymId }];
    if( !_store.gymId ) {
        
        NSString *msg = @"A gym must be selected in order to browse its schedule.";
        [Flurry logError:@"No Gym Selected" message:msg error:nil];
        
        [[[UIAlertView alloc] initWithTitle:@"No Gym Selected"
                                    message:msg
                                   delegate:nil
                          cancelButtonTitle:@"ok"
                          otherButtonTitles:nil
          ] show];
        
        return;
    }
    
    [_store logout];
    [CSWMembership sharedMembership].loginDesired = NO;
    
    [self.navigationController pushViewController:[CSWPrimaryViewController new] animated:TRUE];
}

-(IBAction)logoutPressed:(id)sender
{
    [Flurry logEvent:kLogoutPressed];
    CSWMembership *membership = [CSWMembership sharedMembership];
    [membership setCredentialsWithUsername:@"" withPassword:@""];
    membership.loginDesired = NO;

    [[CSWScheduleStore sharedStore] logout];

    [self updateButtonStatuses];
}

-(void)loginPressed:(id)sender
{
    [self.view endEditing:YES];

    if( ![CSWScheduleStore sharedStore].gymId ) {
        
        NSString *msg = @"A gym must be selected in order to login.";
        [Flurry logError:@"No Gym Selected" message:msg error:nil];
        
        [[[UIAlertView alloc] initWithTitle:@"No Gym Selected"
                                   message:msg
                                  delegate:nil
                         cancelButtonTitle:@"ok"
                         otherButtonTitles:nil
          ] show];
        return;
    }
    
    if ( [self.emailTextField.text isEqualToString:@""] || [self.passwordTextField.text isEqualToString:@""] ) {
        
        NSString *msg = @"Both email and password must be specified in order to login.";

        //no flurry for this

        [[[UIAlertView alloc] initWithTitle:@"Credentials Error"
                                    message:msg
                                   delegate:nil
                          cancelButtonTitle:@"ok"
                          otherButtonTitles:nil
          ] show];
        return;
    }

    CSWScheduleStore *store = [CSWScheduleStore sharedStore];
    CSWMembership *membership = [CSWMembership sharedMembership];
    
    [membership setCredentialsWithUsername:self.emailTextField.text withPassword:self.passwordTextField.text];
    
//    [store logout];

    [self.networkActivity startAnimating];
    
    [Flurry logEvent:kUserLoggingIn
      withParameters:@{ @"reason" : @"loginPressed"
                       ,@"gymId"  : store.gymId
                      }
               timed:YES
     ];
    
    [store loginUserForcefully:YES withCompletion:^(NSError *error) {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            [self.networkActivity stopAnimating];
        
            if ( error ) {
                
                [Flurry endTimedEvent:kUserLoggingIn withParameters:@{ @"success" : @"N" }];
                
                NSString *msg;
                if ( error.code == kErrorCodeCouldNotGetToken ) {
                    msg = @"Unable to connect to the gym's scheduling system.";
                } else if ( error.code == kErrorCodeInvalidCredentials ) {
                    [Flurry logEvent:kLoginBadCredentials];
                    msg = @"Credentials appear to be invalid.";
                } else {
                    msg = [error localizedDescription];
                }
                
                [Flurry logError:@"Unable to Login" message:msg error:error];

                [[[UIAlertView alloc] initWithTitle:@"Unable to Login"
                                            message:msg
                                           delegate:nil
                                  cancelButtonTitle:@"ok"
                                  otherButtonTitles:nil] show];
                
            } else {
                
                [Flurry endTimedEvent:kUserLoggingIn withParameters:@{ @"success" : @"Y" }];
            }
            
            if ( store.isLoggedIn ) {
                
                CSWPrimaryViewController *vc = [CSWPrimaryViewController new];
                [self.navigationController pushViewController:vc
                                                     animated:TRUE
                 ];
                
                membership.loginDesired = YES;
                [membership persistSave];
                
                
            }
        }];
    }];
}

-(void)refreshPressed:(id)sender
{
    [self dismissGymSelector:nil];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.title = @"This will force all data to be refreshed from the network.  Are you sure you want to do this?";
    sheet.delegate = self;
    [sheet addButtonWithTitle:@"go ahead"];
    [sheet addButtonWithTitle:@"nevermind"];
    sheet.cancelButtonIndex = 1;
    sheet.destructiveButtonIndex = 1;
    
    [Flurry logEvent:kRefreshPressed];
    
    [sheet showFromToolbar:self.navigationController.toolbar];
}

//
#pragma mark instance methods (private)
//
-(void)configureView
{
    CSWMembership *membership = [CSWMembership sharedMembership];
    
    if ( membership.gymId ) {
        
        self.selectGymLabel.hidden = TRUE;
        self.gymLongNameLabel.hidden = FALSE;
        self.gymLongNameLabel.text = [[CSWScheduleStore sharedStore] fetchGymConfigValue:@"displayLongName"];
        self.emailTextField.text = membership.username;
        self.passwordTextField.text = membership.password;
        
    } else {
        
        self.selectGymLabel.hidden = FALSE;
        self.gymLongNameLabel.hidden = TRUE;
    }
}

//
#pragma mark CSWGymSelector delegate methods
//
-(void)dismissGymSelector:(id)sender
{
    CSWScheduleStore *store = [CSWScheduleStore sharedStore];
    
    if ( self.gymSelector.shouldAddNewGym ) {
        
        [Flurry logEvent:kDidVisitAddGymPage];
        
        [[[UIAlertView alloc] initWithTitle:kAddGymTitle
                                    message:[store fetchGymConfigValue:@"addGymMessage"]
                                   delegate:self
                          cancelButtonTitle:@"ok"
                          otherButtonTitles:@"take me there now", nil
          ] show];
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             _blackoutButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.0];
                         }
                         completion:^(BOOL finished){
                             [_blackoutButton removeFromSuperview];
                             [self configureView];
                         }
         ];
        
        CGSize gsSize = self.gymSelector.view.frame.size;
        
        [UIView animateWithDuration:0.25
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             self.gymSelector.view.frame = CGRectMake(0,self.view.frame.size.height, gsSize.width, gsSize.height);
                         }
                         completion:^(BOOL finished){
                             [self.gymSelector.view removeFromSuperview];
                             self.selectGymButton.enabled = TRUE;
                         }
         ];

        return;
    }
    
    NSString *gymId = self.gymSelector.selectedGymId;
    
    if ( gymId ) {
        
        if ( ![store.gymId isEqualToString:gymId] ) {
            [store logout];
        }
        
        [[CSWMembership sharedMembership] setContextToGymId:gymId];
        
    } else {
        
        [store logout];
    }
    
    [self.networkActivity startAnimating];
    
    [_backgroundQueue addOperationWithBlock:^{
        
        NSError *error = nil;
        if ( gymId ) [store setupForGymId:gymId error:&error];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            //[self.view sendSubviewToBack:self.networkActivity];
            [self.networkActivity stopAnimating];
            
            if ( error ) {

                NSString *msg = [NSString stringWithFormat:@"could not setup for gym %@: %@", gymId, [error localizedDescription]];
                
                [Flurry logError:error.domain message:msg error:error];
                
                [[[UIAlertView alloc] initWithTitle:error.domain
                                            message:msg
                                           delegate:nil
                                  cancelButtonTitle:@"ok"
                                  otherButtonTitles:nil
                  ] show];
                
                self.selectGymLabel.hidden = NO;
            }
            
            [self updateButtonStatuses];
            
            NSString *longName = self.gymSelector.configForSelectedGymId[@"displayLongName"];
            if ( ![longName isEqualToString:@""] ) {
                
                self.gymLongNameLabel.text = longName;
                self.selectGymLabel.hidden = YES;
                
            } else {
                
                self.selectGymLabel.hidden = NO;
            }
            
            [UIView animateWithDuration:0.25
                             animations:^{
                                 _blackoutButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.0];
                             }
                             completion:^(BOOL finished){
                                 [_blackoutButton removeFromSuperview];
                                 [self configureView];
                             }
             ];
            
            CGSize gsSize = self.gymSelector.view.frame.size;
            
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                                 self.gymSelector.view.frame = CGRectMake(0,self.view.frame.size.height, gsSize.width, gsSize.height);
                             }
                             completion:^(BOOL finished){
                                 [self.gymSelector.view removeFromSuperview];
                                 self.selectGymButton.enabled = TRUE;
                             }
             ];
        }];
    }];
}


-(void)updateButtonStatuses
{
    CSWScheduleStore *store = [CSWScheduleStore sharedStore];
    
    if ( store.isLoggedIn ) {
        
        self.logoutButton.hidden  = NO;
        self.logoutButton.enabled = YES;
        
        self.skipButton.hidden    = YES;
        self.skipButton.enabled   = NO;
        
    } else {
        
        self.logoutButton.hidden  = YES;
        self.logoutButton.enabled = NO;
        
        self.skipButton.hidden    = NO;
        self.skipButton.enabled   = YES;
    }
}


-(void)longNameWasSet:(NSString *)aName
{
    self.gymLongNameLabel.text = aName;
}

////
#pragma mark UITextFieldDelegate
////
-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    if ( !_escapeTextEntryButton ) {
        _escapeTextEntryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _escapeTextEntryButton.frame = self.view.bounds;
        _escapeTextEntryButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        [_escapeTextEntryButton addTarget:self
                                   action:@selector(backgroundButtonPressed:)
                         forControlEvents:UIControlEventTouchUpInside
         ];
        [self.view addSubview:_escapeTextEntryButton];
        [self.view sendSubviewToBack:_escapeTextEntryButton];
    }

    _escapeTextEntryButton.hidden = NO;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    _escapeTextEntryButton.hidden = YES;
    [self.view endEditing:YES];
    return YES;
}

-(void)backgroundButtonPressed:(id)sender
{
    _escapeTextEntryButton.hidden = YES;
    [self.view endEditing:YES];
}

//
#pragma mark UIActionSheetDelegate Protocol Methods
//
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ( buttonIndex == 0 ) { // "confirm refresh all confirmations"
        
        [[CSWScheduleStore sharedStore] unloadAllConfigurations];
        [[CSWMembership sharedMembership] unloadAllConfigurations];
        
        self.gymSelector = nil;
        
        NSManagedObjectContext *moc = [(CSWAppDelegate *)[[UIApplication sharedApplication] delegate] managedObjectContext];
        
        [CSWWorkout purgeAllWorkoutsForGymId:nil withMoc:moc];
        [CSWWod purgeAllWodsForGymId:nil withMoc:moc];
        [CSWWeek purgeAllWeeksForGymId:nil withMoc:moc];
        [CSWInstructor purgeAllInstructorsForGymId:nil withMoc:moc];
        [CSWLocation purgeAllLocationsForGymId:nil withMoc:moc];
        [CSWDayMarker purgeAllDayMarkersWithMoc:moc];
        [moc save:NULL];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self selectGymPressed:nil];
        }];
    }
}

////
#pragma mark UIAlertViewDelegate Protocol Methods
////
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ( [alertView.title isEqualToString:kAddGymTitle] && buttonIndex == 1 ) {
        NSURL *url = [NSURL URLWithString:[_store fetchGymConfigValue:@"addGymUrl"]];
        [[UIApplication sharedApplication] openURL:url];
    }
}

@end
