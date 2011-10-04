//
//  RootViewController.m
//  MealTime
//
//  Created by Peter Shih on 8/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"
#import "PlaceCell.h"
#import "PlaceDataCenter.h"
#import "DetailViewController.h"
#import "SearchTermController.h"
#import "PSLocationCenter.h"
#import "PSSearchCenter.h"
#import "ActionSheetPicker.h"
#import "ListViewController.h"
#import "InfoViewController.h"
#import "PSSearchField.h"
#import "PSOverlayImageView.h"
#import "PSReachabilityCenter.h"

@interface RootViewController (Private)
// View Setup
- (void)setupHeader;
- (void)setupToolbar;

- (void)updateNumResults;

- (void)editingDidBegin:(UITextField *)textField;
- (void)editingDidEnd:(UITextField *)textField;

- (void)distanceSelectedWithIndex:(NSNumber *)selectedIndex inView:(UIView *)view;

- (void)filter;
- (void)showLists;
- (void)showInfo;
- (void)searchNearby;

- (void)locationAcquired:(NSNotification *)notification;

- (void)configureFilters;

@end

@implementation RootViewController

@synthesize whatQuery = _whatQuery;
@synthesize whereQuery = _whereQuery;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [[PlaceDataCenter defaultCenter] setDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationAcquired:) name:kLocationAcquired object:nil];
    
    _openNow = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterOpenNow"];
    _highlyRated = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterHighlyRated"];
    [self configureFilters];
    
    _pagingStart = 0;
    _pagingCount = 1000;
    _pagingTotal = 1000;
    _whatQuery = nil;
    _whereQuery = nil;
    _numResults = 0;
    _location = nil;
    
    _isSearchActive = NO;
    
    _scrollCount = 0;
  }
  return self;
}

- (void)viewDidUnload {
  [super viewDidUnload];
  
  _whereField.delegate = nil;
  _whatField.delegate = nil;
  _whatTermController.delegate = nil;
  _whereTermController.delegate = nil;
  
  RELEASE_SAFELY(_currentAddress);
  RELEASE_SAFELY(_headerView);
  RELEASE_SAFELY(_tabView);
  RELEASE_SAFELY(_filterButton);
  RELEASE_SAFELY(_whatField);
  RELEASE_SAFELY(_whereField);
  RELEASE_SAFELY(_whatTermController);
  RELEASE_SAFELY(_whereTermController);
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kLocationAcquired object:nil];
  [[PlaceDataCenter defaultCenter] setDelegate:nil];
  [_whatField removeFromSuperview];
  [_whereField removeFromSuperview];
  
  _whereField.delegate = nil;
  _whatField.delegate = nil;
  _whatTermController.delegate = nil;
  _whereTermController.delegate = nil;
  
  _reverseGeocoder.delegate = nil;
  
  RELEASE_SAFELY(_location);
  RELEASE_SAFELY(_headerView);
  RELEASE_SAFELY(_tabView);
  RELEASE_SAFELY(_filterButton);
  RELEASE_SAFELY(_whatField);
  RELEASE_SAFELY(_whereField);
  RELEASE_SAFELY(_whatTermController);
  RELEASE_SAFELY(_whereTermController);
  
  RELEASE_SAFELY(_whatQuery);
  RELEASE_SAFELY(_whereQuery);
  RELEASE_SAFELY(_sortBy);
  RELEASE_SAFELY(_filterPrice);
  RELEASE_SAFELY(_cachedItems);
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

- (UIView *)tableView:(UITableView *)tableView rowBackgroundViewForIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
  UIView *backgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  backgroundView.autoresizingMask = ~UIViewAutoresizingNone;
  backgroundView.backgroundColor = selected ? CELL_SELECTED_COLOR : CELL_BACKGROUND_COLOR;
  return backgroundView;
}

#pragma mark - View
- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [self.navigationController setNavigationBarHidden:YES animated:animated];
  
  // NUX
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasShownRootOverlay"]) {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasShownRootOverlay"];
    NSString *imgName = isDeviceIPad() ? @"nux_overlay_root_pad.png" : @"nux_overlay_root.png";
    PSOverlayImageView *nuxView = [[[PSOverlayImageView alloc] initWithImage:[UIImage imageNamed:imgName]] autorelease];
    nuxView.alpha = 0.0;
    [[UIApplication sharedApplication].keyWindow addSubview:nuxView];
    [UIView animateWithDuration:0.4 animations:^{
      nuxView.alpha = 1.0;
    }];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [_whatField resignFirstResponder];
  [_whereField resignFirstResponder];

}

- (void)loadView {
  [super loadView];
  
  self.view.backgroundColor = [UIColor blackColor];
  
  // Nullview
  NSString *imgError = isDeviceIPad() ? @"nullview_error_pad.png" : @"nullview_error.png";
  NSString *imgEmpty = isDeviceIPad() ? @"nullview_noresults_pad.png" : @"nullview_noresults.png";
  [_nullView setLoadingTitle:@"Loading..."];
  [_nullView setLoadingSubtitle:@"Finding places for you"];
  [_nullView setEmptyImage:[UIImage imageNamed:imgEmpty]];
  [_nullView setErrorImage:[UIImage imageNamed:imgError]];
  [_nullView setIsFullScreen:YES];
  [_nullView setDelegate:self];
  
  // iAd
//  _adView = [self newAdBannerViewWithDelegate:self];
  
  // Table
  [self setupTableViewWithFrame:self.view.bounds andStyle:UITableViewStylePlain andSeparatorStyle:UITableViewCellSeparatorStyleNone];
  
  if (isDeviceIPad()) {
    _tableView.rowHeight = 320.0;
  } else {
    _tableView.rowHeight = 160.0;
  }
  
  // Setup Header
  [self setupHeader];
  
  // Setup Toolbar
  [self setupToolbar];
  
  // Search Term Controller
  [self setupSearchTermController];
  
  // DataSource
  if (_viewHasLoadedOnce) {
    // If this view has already been loaded once, don't reload the datasource
    [self restoreDataSource];
  } else {
    [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#load"];
    [self findMyLocation];
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)setupHeader {
  _headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 44.0)];
  UIImageView *bg = [[[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"bg_navbar.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:1]] autorelease];
  bg.autoresizingMask = ~UIViewAutoresizingNone;
  bg.frame = _headerView.bounds;
  [_headerView addSubview:bg];
  
  // Search Bar
  CGFloat searchWidth = _headerView.width - 20;
  
  _whatField = [[PSSearchField alloc] initWithFrame:CGRectMake(10, 7, searchWidth, 30)];
//  _whatField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _whatField.delegate = self;
  _whatField.autocorrectionType = UITextAutocorrectionTypeNo;
  _whatField.placeholder = @"Find: e.g. pizza, patxi's";
  [_whatField addTarget:self action:@selector(searchTermChanged:) forControlEvents:UIControlEventEditingChanged];
  
//  _whatField.inputAccessoryView = tb;
  
    // Left/Right View
  _whatField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _whatField.leftViewMode = UITextFieldViewModeAlways;
  UIImageView *mag = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon_magnifier.png"]] autorelease];
  mag.contentMode = UIViewContentModeCenter;
  _whatField.leftView = mag;
  
//  _whatField.rightViewMode = UITextFieldViewModeUnlessEditing;
//  UIButton *starButton = [UIButton buttonWithFrame:CGRectMake(0, 0, 20, 20) andStyle:nil target:self action:@selector(saved)];
//  [starButton setImage:[UIImage imageNamed:@"icon_star_silver.png"] forState:UIControlStateNormal];
//  _whatField.rightView = starButton;
  
  _whereField = [[PSSearchField alloc] initWithFrame:CGRectMake(10, 7, searchWidth, 30)];
  _whereField.delegate = self;
  _whereField.autocorrectionType = UITextAutocorrectionTypeNo;
  _whereField.placeholder = @"Current Location";
  [_whereField addTarget:self action:@selector(searchTermChanged:) forControlEvents:UIControlEventEditingChanged];
  
//  _whereField.inputAccessoryView = tb;
  
  // Left/Right View
  _whereField.leftViewMode = UITextFieldViewModeAlways;
  UIImageView *where = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon_where.png"]] autorelease];
  where.contentMode = UIViewContentModeCenter;
  _whereField.leftView = where;
  
//  _whereField.rightViewMode = UITextFieldViewModeUnlessEditing;
//  UIButton *distanceButton = [UIButton buttonWithFrame:CGRectMake(0, 0, 40, 16) andStyle:@"whereRightView" target:nil action:nil];
//  [distanceButton setTitle:[NSString stringWithFormat:@"%.1fmi", _distance] forState:UIControlStateNormal];
//  [distanceButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
//  _whereField.rightView = distanceButton;
  
  _whereField.clearButtonMode = UITextFieldViewModeWhileEditing;
  
  [_headerView addSubview:_whereField];
  [_headerView addSubview:_whatField];
  
  [self setupHeaderWithView:_headerView];
}

- (void)setupToolbar {
  CGFloat tabWidth = isDeviceIPad() ? 100 : 50;
  
  _tabView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 49.0)];
  
  UIButton *star = [UIButton buttonWithFrame:CGRectMake(0, 0, tabWidth, 49) andStyle:@"detailTab" target:self action:@selector(showLists)];
  [star setBackgroundImage:[UIImage stretchableImageNamed:@"tab_btn_left.png" withLeftCapWidth:9 topCapWidth:0] forState:UIControlStateNormal];
  [star setImage:[UIImage imageNamed:@"icon_tab_list.png"] forState:UIControlStateNormal];
  [_tabView addSubview:star];
  
  // Center
  _filterButton = [[UIButton buttonWithFrame:CGRectMake(tabWidth, 0, _tabView.width - (tabWidth * 2), 49) andStyle:@"filterButton" target:self action:@selector(filter)] retain];
  [_filterButton setBackgroundImage:[UIImage stretchableImageNamed:@"tab_btn_center_selected.png" withLeftCapWidth:9 topCapWidth:0] forState:UIControlStateNormal];
  [_filterButton setTitle:@"Determining Your Location" forState:UIControlStateNormal];
//  _filterButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
//  _filterButton.titleLabel.textAlignment = UITextAlignmentCenter;
//  _filterButton.titleLabel.numberOfLines = 2;
  [_tabView addSubview:_filterButton];
  
  UIButton *heart = [UIButton buttonWithFrame:CGRectMake(_tabView.width - tabWidth, 0, tabWidth, 49) andStyle:@"detailTab" target:self action:@selector(showInfo)];
  [heart setBackgroundImage:[UIImage stretchableImageNamed:@"tab_btn_right.png" withLeftCapWidth:9 topCapWidth:0] forState:UIControlStateNormal];
  [heart setImage:[UIImage imageNamed:@"icon_tab_info.png"] forState:UIControlStateNormal];
  [_tabView addSubview:heart];
  
  [self setupFooterWithView:_tabView];
  
//  _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 44.0)];
//  
//  // Toolbar Items
//  NSMutableArray *toolbarItems = [NSMutableArray arrayWithCapacity:1];
//
//  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_star_silver.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showLists)] autorelease]];
//  
//  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
//  
//  _filterButton = [[UIBarButtonItem barButtonWithTitle:[NSString stringWithFormat:@"Searching within %.1f miles", [[NSUserDefaults standardUserDefaults] floatForKey:@"distanceRadius"]] withTarget:self action:@selector(changeDistance) width:(_toolbar.width - 80) height:30 buttonType:BarButtonTypeGray style:@"detailToolbarButton"] retain];
//  [toolbarItems addObject:_filterButton];
//  
//  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
//  
//  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_heart.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showInfo)] autorelease]];
//  
//  [_toolbar setItems:toolbarItems];
//  [self setupFooterWithView:_toolbar];
}

- (void)setupSearchTermController {
  _whatTermController = [[SearchTermController alloc] initWithContainer:@"what"];
  _whatTermController.delegate = self;
//  _whatTermController.view.frame = self.view.bounds;
  _whatTermController.view.frame = CGRectMake(0, 44, self.view.width, self.view.height - 44);
  _whatTermController.view.alpha = 0.0;
  [self.view insertSubview:_whatTermController.view aboveSubview:_headerView];
//  [self.view addSubview:_whatTermController.view];
  
  _whereTermController = [[SearchTermController alloc] initWithContainer:@"where"];
  _whereTermController.delegate = self;
//  _whereTermController.view.frame = self.view.bounds;
  _whereTermController.view.frame = CGRectMake(0, 44, self.view.width, self.view.height - 44)
  ;
  _whereTermController.view.alpha = 0.0;
  [self.view insertSubview:_whereTermController.view aboveSubview:_headerView];
//  [self.view addSubview:_whereTermController.view];
}

#pragma mark - Button Actios
- (void)findMyLocation {
  if ([[PSReachabilityCenter defaultCenter] isNetworkReachable]) {
    [[PSLocationCenter defaultCenter] getMyLocation];
  } else {
    [self dataCenterDidFailWithError:nil andUserInfo:nil];
  }
}

- (void)showLists {
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#showLists"];
  
  ListViewController *lvc = [[ListViewController alloc] initWithListMode:ListModeView];
  UINavigationController *lnc = [[UINavigationController alloc] initWithRootViewController:lvc];
  [self presentModalViewController:lnc animated:YES];
  [lvc release];
  [lnc release];
}

- (void)showInfo {
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#info"];
  
  InfoViewController *ivc = [[InfoViewController alloc] initWithNibName:nil bundle:nil];
  UINavigationController *inc = [[UINavigationController alloc] initWithRootViewController:ivc];
  inc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
  [self presentModalViewController:inc animated:YES];
  [ivc release];
  [inc release];
}

- (void)filter {
  FilterViewController *fvc = [[FilterViewController alloc] initWithOptions:nil];
  fvc.delegate = self;
  fvc.modalTransitionStyle = UIModalTransitionStylePartialCurl;
  [self presentModalViewController:fvc animated:YES];
  [fvc release];
  
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#filter"];
  return;
}

- (void)searchNearby {
  _whereField.text = nil;
  self.whereQuery = nil;
  _pagingStart = 0;
  [self loadDataSource];
}

- (void)updateNumResults {
//  NSString *where = [_whereField.text length] > 0 ? _whereField.text : @"Current Location";
  NSString *distanceTitle = nil;
  if (_numResults > 0) {
    distanceTitle = [NSString stringWithFormat:@"Showing %d Places", _numResults];
  } else {
    distanceTitle = [NSString stringWithFormat:@"No Places Found"];
  }
  [_filterButton setTitle:distanceTitle forState:UIControlStateNormal];
}

#pragma mark - Fetching Data
- (void)fetchDataSource {
  BOOL isReload = (_pagingStart == 0) ? YES : NO;
  
  if (isReload) {    
    // Update distance button label
    [_filterButton setTitle:[NSString stringWithFormat:@"Searching for Places"] forState:UIControlStateNormal];
    
    // Update location param
    _location = self.whereQuery ? [[NSString stringWithFormat:@"find_loc=%@", [self.whereQuery stringByURLEncoding]] retain] : [[NSString stringWithFormat:@"l=a:%f,%f,%g", [[PSLocationCenter defaultCenter] latitude], [[PSLocationCenter defaultCenter] longitude], [[PSLocationCenter defaultCenter] accuracy]] retain];
  }
  
  NSDictionary *localyticsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  self.whatQuery ? self.whatQuery : @"",
                                  @"what",
                                  self.whereQuery ? self.whereQuery : @"",
                                  @"where",
                                  [NSString stringWithFormat:@"%d", _pagingStart],
                                  @"pagingStart",
                                  [NSString stringWithFormat:@"%d", _pagingCount],
                                  @"pagingCount",
                                  _location,
                                  @"location",
                                  nil];
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#fetch" attributes:localyticsDict];
  
  // 1608m/mi
  // 8046 - 5mi
  // 4828 - 3mi
  
  NSInteger price = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterPrice"];

  [[PlaceDataCenter defaultCenter] fetchPlacesForQuery:_whatQuery location:_location radius:@"4828" sortby:nil openNow:_openNow price:0 start:_pagingStart rpp:_pagingCount];
}

#pragma mark - State Machine
- (BOOL)shouldLoadMore {
  return NO;
}

- (void)loadMore {
  [super loadMore];
  _pagingTotal += _pagingCount;
  _pagingStart += _pagingCount; // load another page
  
  [self fetchDataSource];
}

- (void)restoreDataSource {
  [super restoreDataSource];
  
  [self updateNumResults];
  _whereField.text = _whereQuery;
  _whatField.text = _whatQuery;
}

- (void)reloadDataSource {
  [super reloadDataSource];
  _pagingStart = 0;
  [self loadDataSource];
}

- (void)loadDataSource {
  BOOL isReload = (_pagingStart == 0) ? YES : NO;
  if (isReload) {
    _hasMore = NO;
    [self.items removeAllObjects];
    [self.tableView reloadData];
  }
  
  [super loadDataSource];
  [self fetchDataSource];
}

- (void)dataSourceDidLoad {
  BOOL isReload = (_pagingStart == 0) ? YES : NO;
  
  if (isReload) {
    [super dataSourceDidLoad];
  } else {
    [super dataSourceDidLoadMore];
  }
}

- (void)dataSourceDidLoadMore {
  [super dataSourceDidLoadMore];
}


#pragma mark - PSDataCenterDelegate
- (void)dataCenterDidFinishWithResponse:(id)response andUserInfo:(NSDictionary *)userInfo {
  // Check hasMore
  NSDictionary *paging = [response objectForKey:@"paging"];
  NSInteger currentPage = [[paging objectForKey:@"currentPage"] integerValue];
  NSInteger numPages = [[paging objectForKey:@"numPages"] integerValue];
  if (currentPage == (numPages - 1)) {
    _hasMore = NO;
  } else {
    _hasMore = YES;
  }
  
  // Num results
  _numResults = [response objectForKey:@"numResults"] ? [[response objectForKey:@"numResults"] integerValue] : 0;
  [self updateNumResults];
  
  NSMutableArray *places = [response objectForKey:@"places"];
  
  // Let's get rid of all places with empty photos
  
  RELEASE_SAFELY(_cachedItems);
  _cachedItems = [[NSMutableArray alloc] initWithArray:places];
  
  [_cachedItems filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT coverPhoto CONTAINS[cd] 'blank'"]];
    
  NSMutableArray *filteredPlaces = [NSMutableArray arrayWithArray:_cachedItems];
  
  // Price filter
  NSMutableString *predFmt = [NSMutableString string];
  
  if (_filterPrice) {
    [predFmt appendFormat:@"price like '%@'", _filterPrice];
  }
  
  // Highly Rated filter
  if (_highlyRated) {
    NSString *and = _filterPrice ? @" AND " : @"";
    [predFmt appendFormat:@"%@numReviews > %d AND score > %d", and, HIGHLY_RATED_REVIEWS, HIGHLY_RATED_SCORE];
  }
  
  if ([predFmt length] > 0) {
    [filteredPlaces filterUsingPredicate:[NSPredicate predicateWithFormat:predFmt]];
  }
  
  // Sort places based on filter
  if (_sortBy) {
    BOOL ascending = [_sortBy isEqualToString:@"distance"];
    [filteredPlaces sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:_sortBy ascending:ascending]]];
  }
  
  // Calculate number of places shown
  NSString *numPlaces = nil;
  if ([filteredPlaces count] > 0) {
    numPlaces = [NSString stringWithFormat:@"Showing %d Places", [filteredPlaces count]];
  } else {
    numPlaces = [NSString stringWithFormat:@"No Places Found"];
  }
  [_filterButton setTitle:numPlaces forState:UIControlStateNormal];
  
  BOOL isReload = (_pagingStart == 0) ? YES : NO;
  if (isReload) {
    [self dataSourceShouldLoadObjects:[NSMutableArray arrayWithObject:filteredPlaces] shouldAnimate:NO];
  } else {
    [self dataSourceShouldLoadMoreObjects:filteredPlaces forSection:0 shouldAnimate:YES];
  }
  
}

- (void)dataCenterDidFailWithError:(NSError *)error andUserInfo:(NSDictionary *)userInfo {
  [self dataSourceDidError];
  [_filterButton setTitle:@"GPS/Network Error" forState:UIControlStateNormal];
}

#pragma mark - Actions
- (void)locationAcquired:(NSNotification *)notification {
  [self loadDataSource];
}

- (void)reverseGeocode {
  if (_reverseGeocoder && _reverseGeocoder.querying) {
    return;
  } else {
    // NYC (Per Se): 40.76848, -73.98264
    // Paris: 48.86930, 2.37151
    // London (Gordon Ramsay): 51.48476, -0.16308
    // Alexanders: 37.32798, -122.01382
    // Bouchon: 38.40153, -122.36049
    CGFloat latitude = [[PSLocationCenter defaultCenter] latitude];
    CGFloat longitude = [[PSLocationCenter defaultCenter] longitude];
    
    DLog(@"Attempting Reverse Geocode for lat: %f, lng: %f", latitude, longitude);
    
    RELEASE_SAFELY(_reverseGeocoder);
    _reverseGeocoder = [[MKReverseGeocoder alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];    
    _reverseGeocoder.delegate = self;
    [_reverseGeocoder start];
  }
}

#pragma mark - MKReverseGeocoderDelegate
- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark {
  NSDictionary *address = placemark.addressDictionary;
  DLog(@"Reverse Geocode got address: %@", address);
  
  // Create some edge cases for weird stuff
  
  RELEASE_SAFELY(_currentAddress);
  _currentAddress = [[NSArray arrayWithObjects:[[address objectForKey:@"FormattedAddressLines"] objectAtIndex:0], [[address objectForKey:@"FormattedAddressLines"] objectAtIndex:1], nil] retain];
  
  // fetch Yelp Places
  _pagingStart = 0; // reset paging
  [self fetchDataSource];
}

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error {
  DLog(@"Reverse Geocoding for lat: %f lng: %f FAILED!", geocoder.coordinate.latitude, geocoder.coordinate.longitude);
  
//  UIAlertView *av = [[[UIAlertView alloc] initWithTitle:@"GPS" message:@"Error finding your location" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Try Again", nil] autorelease];
//  av.tag = kAlertGPSError;
//  [av show];
  
  [self dataCenterDidFailWithError:nil andUserInfo:nil];
}

- (void)updateCurrentLocation {
}


#pragma mark - TableView
//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//  return [NSString stringWithFormat:@"%d places within %.1f mile(s)", _numResults, _distance];
//}

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//  UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.width, 30)] autorelease];
//  headerView.autoresizingMask = ~UIViewAutoresizingNone;
//  headerView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg_section_header.png"]];
//  return headerView;
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
//  return 30.0;
//}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//  return [PlaceCell rowHeight];
//}

- (void)tableView:(UITableView *)tableView configureCell:(id)cell atIndexPath:(NSIndexPath *)indexPath {
  NSMutableDictionary *object = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
  [cell fillCellWithObject:object];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  PlaceCell *cell = nil;
  NSString *reuseIdentifier = [PlaceCell reuseIdentifier];
  
  cell = (PlaceCell *)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
  if(cell == nil) { 
    cell = [[[PlaceCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
    [_cellCache addObject:cell];
  }
  
  [self tableView:tableView configureCell:cell atIndexPath:indexPath];
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  NSMutableDictionary *place = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
  
  DetailViewController *dvc = [[DetailViewController alloc] initWithPlace:place];
  [self.navigationController pushViewController:dvc animated:YES];
  [dvc release];
}

#pragma mark - Search
- (void)searchTermChanged:(UITextField *)textField {
  if ([textField isEqual:_whatField]) {
    [_whatTermController searchWithTerm:textField.text];
  } else {
    [_whereTermController searchWithTerm:textField.text];
  }
}

- (void)executeSearch {
  [self dismissSearch];
  
  // What
  if ([_whatField.text length] > 0) {
    // Store search term
    [[PSSearchCenter defaultCenter] addTerm:_whatField.text inContainer:@"what"];
    
    self.whatQuery = _whatField.text;
  } else {
    self.whatQuery = nil;
  }
  
  // Where
  if ([_whereField.text isEqualToString:@"Current Location"]) {
    // Current Location
    self.whereQuery = nil;
  } else if ([_whereField.text length] > 0) {
    // Store search term
    [[PSSearchCenter defaultCenter] addTerm:_whereField.text inContainer:@"where"];
    
    self.whereQuery = _whereField.text;;
  } else {
    // Current Location
    self.whereQuery = nil;
  }
  
  NSDictionary *localyticsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  self.whatQuery ? self.whatQuery : @"",
                                  @"what",
                                  self.whereQuery ? self.whereQuery : @"",
                                  @"where",
                                  nil];
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#search" attributes:localyticsDict];

  // Reload dataSource
    _pagingStart = 0; // reset paging
  [self loadDataSource];
}

- (void)dismissSearch {
  _isSearchActive = NO;
  
  // Animate Search Fields
  [UIView animateWithDuration:0.4
                   animations:^{
                     _whatTermController.view.frame = CGRectMake(0, 44, self.view.width, self.view.height - 44);
                     _whereTermController.view.frame = CGRectMake(0, 44, self.view.width, self.view.height - 44);
                     _headerView.height = 44;
                     _nullView.frame = CGRectMake(0, 44, _nullView.width, _nullView.height + 36);
                     _whereField.top = 7;
                   }
                   completion:^(BOOL finished) {
                   }];
  
  [_whatField resignFirstResponder];
  [_whereField resignFirstResponder];
}

#pragma mark - SearchTermDelegate
- (void)searchTermSelected:(NSString *)searchTerm inContainer:(NSString *)container {
  if ([container isEqualToString:@"what"]) {
    _whatField.text = searchTerm;
  } else {
    _whereField.text = searchTerm;
  }
}

- (void)searchCancelled {
  [self dismissSearch];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
  return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  if (!_isSearchActive) {
    _isSearchActive = YES;
    
    if ([textField isEqual:_whatField]) {
      [_whatTermController searchWithTerm:textField.text];
    } else {
      [_whereTermController searchWithTerm:textField.text];
    }
    
    // Animate Search Fields
    [UIView animateWithDuration:0.4
                     animations:^{
                       _whatTermController.view.frame = CGRectMake(0, 80, self.view.width, self.view.height - 80);
                       _whereTermController.view.frame = CGRectMake(0, 80, self.view.width, self.view.height - 80);
                       _headerView.height = 80;
                       _nullView.frame = CGRectMake(0, 80, _nullView.width, _nullView.height - 36);
                       _whereField.top = 42;
                     }
                     completion:^(BOOL finished) {
                     }];
  }
  
  if ([textField isEqual:_whatField]) {
    [self.view bringSubviewToFront:_whatTermController.view];
    _whatTermController.view.alpha = 1.0;
  } else {
    [self.view bringSubviewToFront:_whereTermController.view];
    _whereTermController.view.alpha = 1.0;
  }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  if ([textField isEqual:_whatField]) {
    _whatTermController.view.alpha = 0.0;
  } else {
    _whereTermController.view.alpha = 0.0;
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  if (![textField isEditing]) {
    [textField becomeFirstResponder];
  }
  
  [self executeSearch];
  
  return YES;
}

#pragma mark - UIScrollViewDelegate
//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//  [super scrollViewDidScroll:scrollView];
//  
//  if (_scrollCount == 0) {
//    _scrollCount++;
//    [_cellCache makeObjectsPerformSelector:@selector(pauseAnimations)];
//  }
//}
//
//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
//  [super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
//  
//  if (!decelerate && (_scrollCount == 1)) {
//    _scrollCount--;
//    [_cellCache makeObjectsPerformSelector:@selector(resumeAnimations)];
//  }
//  
//}
//
//- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//  [super scrollViewDidEndDecelerating:scrollView];
//  
//  if (_scrollCount == 1) {
//    _scrollCount--;
//    [_cellCache makeObjectsPerformSelector:@selector(resumeAnimations)];
//  }
//}

#pragma mark - UIAlertView
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.cancelButtonIndex) return;
  
  if (alertView.tag == kAlertGPSError) {
    [self loadDataSource];
  }
  
}

- (void)configureFilters {
  RELEASE_SAFELY(_sortBy);
  NSInteger sortByIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterSortBy"];
  switch (sortByIndex) {
    case 0: // best_match
      _sortBy = nil;
      break;
    case 1: // distance
      _sortBy = [@"distance" retain];
      break;
    case 2: // rating
      _sortBy = [@"score" retain];
      break;
    default:
      _sortBy = nil;
      break;
  }
  
  RELEASE_SAFELY(_filterPrice);
  NSInteger priceIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"filterPrice"];
  switch (priceIndex) {
    case 0:
      _filterPrice = nil;
      break;
    case 1:
      _filterPrice = @"$";
      break;
    case 2:
      _filterPrice = @"$$";
      break;
    case 3:
      _filterPrice = @"$$$";
      break;
    case 4:
      _filterPrice = @"$$$$";
      break;
    default:
      _filterPrice = nil;
      break;
  }
}

- (void)filterDidSelectWithOptions:(NSDictionary *)options sender:(id)sender {
  [self configureFilters];
  
  _highlyRated = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterHighlyRated"];

  if (_openNow != [[NSUserDefaults standardUserDefaults] boolForKey:@"filterOpenNow"]) {
    _openNow = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterOpenNow"];
    // Fire a refetch if openNow was toggled to ON
    _pagingStart = 0;
    [self loadDataSource];
    return;
  }
  
  NSMutableArray *filteredPlaces = [NSMutableArray arrayWithArray:_cachedItems];
  
  // Price filter
  NSMutableString *predFmt = [NSMutableString string];
  
  if (_filterPrice) {
    [predFmt appendFormat:@"price like '%@'", _filterPrice];
  }
  
  if (_highlyRated) {
    NSString *and = _filterPrice ? @" AND " : @"";
    [predFmt appendFormat:@"%@numReviews > %d AND score > %d", and, HIGHLY_RATED_REVIEWS, HIGHLY_RATED_SCORE];
  }

  if ([predFmt length] > 0) {
    [filteredPlaces filterUsingPredicate:[NSPredicate predicateWithFormat:predFmt]];
  }
  
  // Sort places based on filter
  if (_sortBy) {
    BOOL ascending = [_sortBy isEqualToString:@"distance"];
    [filteredPlaces sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:_sortBy ascending:ascending]]];
  }
  
  // Calculate number of places shown
  NSString *numPlaces = nil;
  if ([filteredPlaces count] > 0) {
    numPlaces = [NSString stringWithFormat:@"Showing %d Places", [filteredPlaces count]];
  } else {
    numPlaces = [NSString stringWithFormat:@"No Places Found"];
  }
  [_filterButton setTitle:numPlaces forState:UIControlStateNormal];
  
  [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
  [self dataSourceShouldLoadObjects:[NSMutableArray arrayWithObject:filteredPlaces] shouldAnimate:NO];
}

@end
