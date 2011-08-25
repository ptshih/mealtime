//
//  RootViewController.h
//  Spotlight
//
//  Created by Peter Shih on 8/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "PSTableViewController.h"

@interface RootViewController : PSTableViewController <MKReverseGeocoderDelegate> {
  
}

- (void)reverseGeocode;

@end
