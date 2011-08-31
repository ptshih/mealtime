//
//  PlaceAnnotation.m
//  MealTime
//
//  Created by Peter Shih on 8/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PlaceAnnotation.h"

@implementation PlaceAnnotation

- (id)initWithPlace:(NSDictionary *)place {
  self = [super init];
  if (self) {
    _place = place; // assign
  }
  return self;
}

- (CLLocationCoordinate2D)coordinate {
	CLLocationCoordinate2D coordinate;
#ifdef USE_FAKE_LAT_LNG
	coordinate.longitude = -122.4100;
	coordinate.latitude = 37.7805;
#else
	coordinate.latitude = [[_place objectForKey:@"latitude"] floatValue];
	coordinate.longitude = [[_place objectForKey:@"longitude"] floatValue];
#endif
	return coordinate;
}

- (NSString *)title {
  return [_place objectForKey:@"name"];
}

// optional
- (NSString *)subtitle {
  return [[_place objectForKey:@"address"] componentsJoinedByString:@" "];
}

@end
