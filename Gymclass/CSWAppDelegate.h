//
//  CSWAppDelegate.h
//  Gymclass
//
//  Created by Eric Colton on 11/21/12.
//  Copyright (c) 2012 Cindy Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSWPrimaryViewController.h"

@interface CSWAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
