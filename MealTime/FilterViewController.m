//
//  FilterViewController.m
//  MealTime
//
//  Created by Peter Shih on 10/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FilterViewController.h"

#define MARGIN_X 10.0
#define MARGIN_Y 10.0

@implementation FilterViewController

@synthesize delegate = _delegate;

- (id)initWithOptions:(NSDictionary *)options {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _filterChanged = NO;
  }
  return self;
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (void)dealloc {
  [super dealloc];
}

#pragma mark - View Config
- (UIView *)backgroundView {
  NSString *imgName = isDeviceIPad() ? @"bg_darkwood_pad.jpg" : @"bg_darkwood.jpg";
  UIImageView *bg = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:imgName]] autorelease];
  bg.frame = self.view.bounds;
  bg.autoresizingMask = ~UIViewAutoresizingNone;
  return bg;
}

- (void)loadView {
  [super loadView];
  
  UITapGestureRecognizer *gr = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(done)] autorelease];
  gr.delegate = self;
  [self.view addGestureRecognizer:gr];
  
  // Sortby
  UISegmentedControl *sortby = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Smart", @"Distance", @"Rating", nil]] autorelease];
  sortby.segmentedControlStyle = UISegmentedControlStyleBordered;
  [sortby addTarget:self action:@selector(sortbyChanged:) forControlEvents:UIControlEventValueChanged];
  sortby.frame = CGRectMake(0, 0, 300, 44);
  [self.view addSubview:sortby];
  
  // Price
  UISegmentedControl *price = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"All", @"$", @"$$", @"$$$", @"$$$$", nil]] autorelease];
  price.segmentedControlStyle = UISegmentedControlStyleBordered;
  [price addTarget:self action:@selector(priceChanged:) forControlEvents:UIControlEventValueChanged];
  price.frame = CGRectMake(0, 0, 300, 44);
  [self.view addSubview:price];
  
  // Open Now
  UIView *openNowView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 44)] autorelease];
  // bg
  UIImageView *onvbg = [[[UIImageView alloc] initWithImage:[UIImage stretchableImageNamed:@"grouped_full_cell.png" withLeftCapWidth:6 topCapWidth:6]] autorelease];
  onvbg.frame = openNowView.bounds;
  [openNowView addSubview:onvbg];
  
  // Switch
  UISwitch *openNowSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
  [openNowSwitch addTarget:self action:@selector(openNowChanged:) forControlEvents:UIControlEventValueChanged];
  openNowSwitch.left = openNowView.width - 102;
  openNowSwitch.top = 9;
  [openNowView addSubview:openNowSwitch];
  
  // label
  UILabel *openNowLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  openNowLabel.frame = CGRectMake(10, 0, openNowView.width - 90, openNowView.height);
  openNowLabel.backgroundColor = [UIColor clearColor];
  openNowLabel.font = [PSStyleSheet fontForStyle:@"openNowLabel"];
  openNowLabel.textColor = [PSStyleSheet textColorForStyle:@"openNowLabel"];
  openNowLabel.text = @"Show Places Open Now";
  [openNowView addSubview:openNowLabel];
  [self.view addSubview:openNowView];
  
  // Highly Rated
  UIView *hrView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 44)] autorelease];
  // bg
  UIImageView *hrbg = [[[UIImageView alloc] initWithImage:[UIImage stretchableImageNamed:@"grouped_full_cell.png" withLeftCapWidth:6 topCapWidth:6]] autorelease];
  hrbg.frame = hrView.bounds;
  [hrView addSubview:hrbg];
  
  // Switch
  UISwitch *hrSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
  [hrSwitch addTarget:self action:@selector(highlyRatedChanged:) forControlEvents:UIControlEventValueChanged];
  hrSwitch.left = hrView.width - 102;
  hrSwitch.top = 9;
  [hrView addSubview:hrSwitch];
  
  // label
  UILabel *hrLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  hrLabel.frame = CGRectMake(10, 0, hrView.width - 90, hrView.height);
  hrLabel.backgroundColor = [UIColor clearColor];
  hrLabel.font = [PSStyleSheet fontForStyle:@"highlyRatedLabel"];
  hrLabel.textColor = [PSStyleSheet textColorForStyle:@"highlyRatedLabel"];
  hrLabel.text = @"Only Show Highly Rated";
  [hrView addSubview:hrLabel];
  [self.view addSubview:hrView];
  
  // Done Button
  UIButton *doneButton = [UIButton buttonWithFrame:CGRectMake(0, 0, 300, 44) andStyle:@"filterDoneButton" target:self action:@selector(done)];
  [doneButton setBackgroundImage:[UIImage stretchableImageNamed:@"grouped_full_cell_highlighted.png" withLeftCapWidth:6 topCapWidth:6] forState:UIControlStateNormal];
  [doneButton setTitle:@"Apply Filters" forState:UIControlStateNormal];
  [self.view addSubview:doneButton];
  
  // Setup Default Selections
  sortby.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterSortBy"];
  price.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterPrice"];
  openNowSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterOpenNow"];
  hrSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterHighlyRated"];
  
  //
  // Layout subviews
  //
  CGFloat top = 110;
  CGFloat left = MARGIN_X;
  
  // Sort By Section
  UILabel *sbl = [UILabel labelWithText:@"Sort By" style:@"filterSectionLabel"];
  sbl.top = top;
  sbl.left = left * 2;
  sbl.width = self.view.width - left * 4;
  sbl.height = 30.0;
  [self.view addSubview:sbl];
  
  top += sbl.height;
  
  sortby.top = top;
  sortby.left = left;
  
  top += sortby.height;
  
  // Price Section
  UILabel *pl = [UILabel labelWithText:@"Price" style:@"filterSectionLabel"];
  pl.top = top;
  pl.left = left * 2;
  pl.width = self.view.width - left * 4;
  pl.height = 30.0;
  [self.view addSubview:pl];
  
  top += pl.height;
  
  price.top = top;
  price.left = left;

  top += price.height + MARGIN_Y * 2;
  
  // Open Now
  openNowView.top = top;
  openNowView.left = left;
  
  top += openNowView.height + MARGIN_Y * 2;
  
  // Highly Rated
  hrView.top = top;
  hrView.left = left;
  
  top += hrView.height + MARGIN_Y * 2;
  
  // Done Button
  doneButton.top = top;
  doneButton.left = left;
  
  [self updateState];
}

- (void)done {
  // tell delegate
  if (_filterChanged && self.delegate && [self.delegate respondsToSelector:@selector(filterDidSelectWithOptions:sender:)]) {
    [self.delegate filterDidSelectWithOptions:nil sender:self];
  }
  [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  if ([touch.view isEqual:self.view]) {
    return YES;
  } else {
    return NO;
  }
}

#pragma mark - Segmented Value Changed
- (void)sortbyChanged:(UISegmentedControl *)segmentedControl {
  NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterSortBy"];
  if (currentIndex != segmentedControl.selectedSegmentIndex) {
    [[NSUserDefaults standardUserDefaults] setInteger:segmentedControl.selectedSegmentIndex forKey:@"filterSortBy"];
    _filterChanged = YES;
  }
}

- (void)priceChanged:(UISegmentedControl *)segmentedControl {
  NSInteger currentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterPrice"];
  if (currentIndex != segmentedControl.selectedSegmentIndex) {
    [[NSUserDefaults standardUserDefaults] setInteger:segmentedControl.selectedSegmentIndex forKey:@"filterPrice"];
    _filterChanged = YES;
  }
}

- (void)openNowChanged:(UISwitch *)aSwitch {
  BOOL currentValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterOpenNow"];
  if (currentValue != aSwitch.on) {
    [[NSUserDefaults standardUserDefaults] setBool:aSwitch.on forKey:@"filterOpenNow"];
    _filterChanged = YES;
  }
}

- (void)highlyRatedChanged:(UISwitch *)aSwitch {
  BOOL currentValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterHighlyRated"];
  if (currentValue != aSwitch.on) {
    [[NSUserDefaults standardUserDefaults] setBool:aSwitch.on forKey:@"filterHighlyRated"];
    _filterChanged = YES;
  }
}

#pragma mark - State Machine
- (BOOL)dataIsAvailable {
  return YES;
}

@end