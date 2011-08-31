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

@implementation RootViewController

@synthesize fetchQuery = _fetchQuery;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [[PlaceDataCenter defaultCenter] setDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reverseGeocode) name:kLocationAcquired object:nil];
    
    _sortBy = [@"popularity" retain];
    _distance = 0.5;
    _pagingStart = 0;
    _pagingCount = 25;
    _pagingTotal = 25;
    _fetchQuery = nil;
    
    _cellCache = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)viewDidUnload {
  [super viewDidUnload];
  RELEASE_SAFELY(_currentLocationLabel);
  RELEASE_SAFELY(_toolbar);
  RELEASE_SAFELY(_searchField);
  RELEASE_SAFELY(_compassButton);
  RELEASE_SAFELY(_cancelButton);
  RELEASE_SAFELY(_searchTermController);
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kLocationAcquired object:nil];
  [[PlaceDataCenter defaultCenter] setDelegate:nil];
  [_searchField removeFromSuperview];
  
  RELEASE_SAFELY(_currentLocationLabel);
  RELEASE_SAFELY(_toolbar);
  RELEASE_SAFELY(_searchField);
  RELEASE_SAFELY(_compassButton);
  RELEASE_SAFELY(_cancelButton);
  RELEASE_SAFELY(_searchTermController);
  
  RELEASE_SAFELY(_cellCache);
  
  RELEASE_SAFELY(_sortBy);
  [super dealloc];
}

#pragma mark - View Config
- (UIView *)backgroundView {
  UIImageView *bg = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bg_darkwood.jpg"]] autorelease];
  bg.frame = self.view.bounds;
  bg.autoresizingMask = ~UIViewAutoresizingNone;
  return bg;
}

- (UIView *)rowBackgroundView {
  UIView *backgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  backgroundView.autoresizingMask = ~UIViewAutoresizingNone;
  backgroundView.backgroundColor = CELL_BACKGROUND_COLOR;
  return backgroundView;
}

- (UIView *)rowSelectedBackgroundView {
  UIView *selectedBackgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  selectedBackgroundView.autoresizingMask = ~UIViewAutoresizingNone;
  selectedBackgroundView.backgroundColor = CELL_SELECTED_COLOR;
  return selectedBackgroundView;
}

#pragma mark - View
- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [_cellCache makeObjectsPerformSelector:@selector(resumeAnimations)];
  
  [UIView animateWithDuration:0.4
                        delay:0.0
   
                      options:UIViewAnimationCurveEaseOut
                   animations:^{
                     _searchField.alpha = 1.0;
                   }
                   completion:^(BOOL finished) {
                   }];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  
  [_cellCache makeObjectsPerformSelector:@selector(pauseAnimations)];
  
  [_searchField resignFirstResponder];
  
  [UIView animateWithDuration:0.4
                        delay:0.0
   
                      options:UIViewAnimationCurveEaseOut
                   animations:^{
                     _searchField.alpha = 0.0;
                   }
                   completion:^(BOOL finished) {
                   }];
}

- (void)loadView {
  [super loadView];
  
  self.view.backgroundColor = [UIColor blackColor];
//  _navTitleLabel.text = @"MealTime";
  
  [_nullView setLoadingTitle:@"Loading..." loadingSubtitle:@"Finding Nearby Restaurants" emptyTitle:@"Fail" emptySubtitle:@"No Restaurants Found" image:[UIImage imageNamed:@"nullview_photos.png"]];
  
  // iAd
//  _adView = [self newAdBannerViewWithDelegate:self];
  
  // Table
  [self setupTableViewWithFrame:self.view.bounds andStyle:UITableViewStylePlain andSeparatorStyle:UITableViewCellSeparatorStyleNone];
  
  if (isDeviceIPad()) {
    _tableView.rowHeight = 320.0;
  } else {
    _tableView.rowHeight = 160.0;
  }
  
  // Toolbar
  _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 44.0)];
  NSMutableArray *toolbarItems = [NSMutableArray arrayWithCapacity:1];

  [toolbarItems addObject:[UIBarButtonItem barButtonWithTitle:@"Sort" withTarget:self action:@selector(sort) width:60 height:30 buttonType:BarButtonTypeSilver]];
  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
  
  UIView *titleView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, _toolbar.width - 60 - 60 - 40, _toolbar.height)] autorelease];
  titleView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  _currentLocationLabel = [[UILabel alloc] initWithFrame:titleView.bounds];
  _currentLocationLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight;
  _currentLocationLabel.textAlignment = UITextAlignmentCenter;
  _currentLocationLabel.numberOfLines = 3;
  _currentLocationLabel.font = [PSStyleSheet fontForStyle:@"currentLocationLabel"];
  _currentLocationLabel.textColor = [PSStyleSheet textColorForStyle:@"currentLocationLabel"];
  _currentLocationLabel.shadowColor = [PSStyleSheet shadowColorForStyle:@"currentLocationLabel"];
  _currentLocationLabel.shadowOffset = CGSizeMake(0, 1);
  _currentLocationLabel.backgroundColor = [UIColor clearColor];
  [titleView addSubview:_currentLocationLabel];
  UIBarButtonItem *currentLocationItem = [[[UIBarButtonItem alloc] initWithCustomView:titleView] autorelease];
  [toolbarItems addObject:currentLocationItem];
  
  [toolbarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
  [toolbarItems addObject:[UIBarButtonItem barButtonWithTitle:@"Distance" withTarget:self action:@selector(filter) width:60 height:30 buttonType:BarButtonTypeSilver]];

  [_toolbar setItems:toolbarItems];
  [self setupFooterWithView:_toolbar];
  
  // Compass location finder
  _compassButton = [[UIBarButtonItem barButtonWithImage:[UIImage imageNamed:@"icon_compass.png"] withTarget:self action:@selector(findMyLocation) width:40 height:30 buttonType:BarButtonTypeBlue] retain];
  self.navigationItem.rightBarButtonItem = _compassButton;
  
  // Setup Search
  _searchField = [[PSTextField alloc] initWithFrame:CGRectMake(5, 26, self.view.width - 80, 30) withInset:CGSizeMake(30, 6)];
  _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
  _searchField.font = NORMAL_FONT;
  _searchField.delegate = self;
  _searchField.returnKeyType = UIReturnKeySearch;
  _searchField.background = [UIImage stretchableImageNamed:@"bg_searchbar_textfield.png" withLeftCapWidth:30 topCapWidth:0];
  _searchField.placeholder = @"Address, City, State or Zip";
  [_searchField addTarget:self action:@selector(searchTermChanged:) forControlEvents:UIControlEventEditingChanged];
  
  [[[UIApplication sharedApplication] keyWindow] addSubview:_searchField];
  
  _cancelButton = [[UIBarButtonItem barButtonWithTitle:@"Cancel" withTarget:self action:@selector(cancelSearch) width:60 height:30 buttonType:BarButtonTypeSilver] retain];
  
  // Search Term Controller
  [self setupSearchTermController];
  
  // Get initial location
  [self loadDataSource];
}

- (void)setupSearchTermController {
  _searchTermController = [[SearchTermController alloc] init];
  _searchTermController.delegate = self;
  _searchTermController.view.frame = self.view.bounds;
  _searchTermController.view.alpha = 0.0;
  [self.view addSubview:_searchTermController.view];
}

#pragma mark - Button Actios
- (void)findMyLocation {
  [[LocalyticsSession sharedLocalyticsSession] tagEvent:@"root#findMyLocation"];
  [[PSLocationCenter defaultCenter] getMyLocation];
  _searchField.text = @"Current Location";
}

- (void)sort {
  [[[[UIAlertView alloc] initWithTitle:@"Oh Noes!" message:@"Broken for now..." delegate:nil cancelButtonTitle:@"Aww" otherButtonTitles:nil] autorelease] show];
  
//  UIActionSheet *as = [[[UIActionSheet alloc] initWithTitle:@"Sort Results" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Popularity", @"Distance", nil] autorelease];
//  as.tag = kSortActionSheet;
//  as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
//  [as showFromToolbar:_toolbar];
}

- (void)filter {
  UIActionSheet *as = [[[UIActionSheet alloc] initWithTitle:@"Distance" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"0.2 miles", @"0.5 miles", @"1.0 miles", @"3.0 miles", @"5.0 miles", nil] autorelease];
  as.tag = kFilterActionSheet;
  as.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
  [as showFromToolbar:_toolbar];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == actionSheet.cancelButtonIndex) return;
  
  switch (actionSheet.tag) {
    case kSortActionSheet:
      switch (buttonIndex) {
        case 0:
          _sortBy = @"index";
          break;
        case 1:
          _sortBy = @"distance";
          break;
        default:
          _sortBy = @"index";
          break;
      }
      // Sort results
//      [self sortResults];
      break;
    case kFilterActionSheet:
      switch (buttonIndex) {
        case 0:
          _distance = 0.2;
          break;
        case 1:
          _distance = 0.5;
          break;
        case 2:
          _distance = 1.0;
          break;
        case 3:
          _distance = 3.0;
          break;
        case 4:
          _distance = 5.0;
          break;
        default:
          _distance = 0.5;
          break;
      }
      // Reload dataSource
      _pagingStart = 0;
      [self loadDataSource];
      break;
    default:
      break;
  }
}

#pragma mark - Sort
- (void)sortResults {
  NSArray *results = [self.items objectAtIndex:0];
  NSArray *sortedResults = [results sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:_sortBy ascending:YES]]];
  [self.items replaceObjectAtIndex:0 withObject:sortedResults];
  [self.tableView reloadData];
}

#pragma mark - Fetching Data
- (void)fetchDataSource {
  [[PlaceDataCenter defaultCenter] fetchYelpPlacesForAddress:self.fetchQuery distance:_distance start:_pagingStart rpp:_pagingCount];
}

#pragma mark - State Machine
- (BOOL)shouldLoadMore {
  return YES;
}

- (void)loadMore {
  _pagingTotal += _pagingCount;
  _pagingStart += _pagingCount; // load another page
  [self loadDataSource];
}

- (void)loadDataSource {
  [super loadDataSource];
  if (_fetchQuery) {
    [self fetchDataSource];
  } else {
    [self findMyLocation];
  }
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
    
    _reverseGeocoder = [[MKReverseGeocoder alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)];    
    _reverseGeocoder.delegate = self;
    [_reverseGeocoder start];
  }
}

#pragma mark - MKReverseGeocoderDelegate
- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark {
  NSDictionary *address = placemark.addressDictionary;
  NSLog(@"add: %@", address);
  
  // Create some edge cases for weird stuff

  NSArray *addressArray = [NSArray arrayWithObjects:[[address objectForKey:@"FormattedAddressLines"] objectAtIndex:0], [[address objectForKey:@"FormattedAddressLines"] objectAtIndex:1], nil];
  NSString *formattedAddress = [addressArray componentsJoinedByString:@" "];
  
  _currentLocationLabel.text = [NSString stringWithFormat:@"%@\n%@", [[address objectForKey:@"FormattedAddressLines"] objectAtIndex:0], [[address objectForKey:@"FormattedAddressLines"] objectAtIndex:1]];
  
  // fetch Yelp Places
  _pagingStart = 0; // reset paging
  self.fetchQuery = formattedAddress;
  [self fetchDataSource];
  
  _reverseGeocoder = nil;
  [geocoder release];
}

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error {
  DLog(@"Reverse Geocoding for lat: %f lng: %f FAILED!", geocoder.coordinate.latitude, geocoder.coordinate.longitude);
  
  _reverseGeocoder = nil;
  [geocoder release];
}

- (void)dataSourceDidLoad {
  if (_pagingStart == 0) {
    [self.tableView setContentOffset:CGPointMake(0, 0)];
  }
  if ([self dataIsAvailable]) {
    [[self.tableView visibleCells] makeObjectsPerformSelector:@selector(setShouldAnimate:) withObject:[NSNumber numberWithBool:NO]];
  }
  [self.tableView reloadData];
  if ([self dataIsAvailable]) {
    [[self.tableView visibleCells] makeObjectsPerformSelector:@selector(setShouldAnimate:) withObject:[NSNumber numberWithBool:YES]];
  }
  [super dataSourceDidLoad];
}

#pragma mark - PSDataCenterDelegate
- (void)dataCenterDidFinish:(ASIHTTPRequest *)request withResponse:(id)response {
  // Check hasMore
  NSDictionary *paging = [response objectForKey:@"paging"];
  NSInteger currentPage = [[paging objectForKey:@"currentPage"] integerValue];
  NSInteger numPages = [[paging objectForKey:@"numPages"] integerValue];
  if (currentPage == numPages) {
    _hasMore = NO;
  } else {
    _hasMore = YES;
  }
  
  // Put response into items (datasource)
  NSArray *places = [response objectForKey:@"places"];
  if ([places count] > 0) {
    if (_pagingStart == 0) {
      // First load
      [self.items removeAllObjects];
      [self.items addObject:places];
    } else {
      // Load more
      NSArray *newPlaces = [[self.items objectAtIndex:0] arrayByAddingObjectsFromArray:places];
      [self.items replaceObjectAtIndex:0 withObject:newPlaces];
    }
  } else {
    [self.items removeAllObjects];
  }
  
  [self dataSourceDidLoad];
}

#pragma mark - TableView
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
  NSMutableDictionary *place = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
  [cell fillCellWithObject:place];
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
- (void)cancelSearch {
//  [UIView animateWithDuration:0.4
//                   animations:^{
//                     _searchField.width = 60;
//                   }
//                   completion:^(BOOL finished) {
//                   }];
  
  self.navigationItem.rightBarButtonItem = _compassButton;
  [_searchField resignFirstResponder];
}

- (void)searchTermChanged:(UITextField *)textField {
  [_searchTermController searchWithTerm:textField.text];
}

- (void)searchWithText:(NSString *)searchText {
  self.navigationItem.rightBarButtonItem = _compassButton;
  [_searchField resignFirstResponder];
  
  if ([searchText isEqualToString:@"Current Location"]) {
    _pagingStart = 0; // reset paging
    self.fetchQuery = nil;
    [self loadDataSource];
  } else {
    // Store search term
    [[PSSearchCenter defaultCenter] addTerm:searchText];
    
    // Search Yelp with Address
    _pagingStart = 0; // reset paging
    self.fetchQuery = searchText;
    [self fetchDataSource];
  }
}

#pragma mark - SearchTermDelegate
- (void)searchTermSelected:(NSString *)searchTerm {
  _searchField.text = searchTerm;
  [self searchWithText:_searchField.text];
}

- (void)searchCancelled {
  [self cancelSearch];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  self.navigationItem.rightBarButtonItem = _cancelButton;
  [self.view bringSubviewToFront:_searchTermController.view];
  _searchTermController.view.alpha = 1.0;
  
//  [UIView animateWithDuration:0.4
//                   animations:^{
//                     _searchField.width = self.view.width - 80;
//                     //                     _searchTermController.view.alpha = 1.0;
//                   }
//                   completion:^(BOOL finished) {
//                   }];
  
  return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {  
  _searchTermController.view.alpha = 0.0;
  return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  if (![textField isEditing]) {
    [textField becomeFirstResponder];
  }
  if ([textField.text length] == 0) {
    // Empty search
    [self cancelSearch];
  } else {
    [self searchWithText:textField.text];
  }
  
  return YES;
}

@end
