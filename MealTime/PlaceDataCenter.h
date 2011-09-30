//
//  PlaceDataCenter.h
//  MealTime
//
//  Created by Peter Shih on 8/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PSDataCenter.h"

@interface PlaceDataCenter : PSDataCenter {
  
}

- (void)getPlacesFromFixtures;

- (void)fetchPlacesForQuery:(NSString *)query location:(NSString *)location radius:(NSString *)radius sortby:(NSString *)sortby openNow:(BOOL)openNow start:(NSInteger)start rpp:(NSInteger)rpp;

- (void)fetchYelpPlacesForQuery:(NSString *)query andAddress:(NSString *)address distance:(CGFloat)distance start:(NSInteger)start rpp:(NSInteger)rpp;
- (void)fetchYelpCoverPhotoForPlaces:(NSMutableArray *)places;
- (void)fetchCoverPhotosForPlace:(NSMutableDictionary *)place placesToRemove:(NSMutableArray *)placesToRemove;

@end
