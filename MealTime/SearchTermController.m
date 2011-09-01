//
//  SearchTermController.m
//  PhotoTime
//
//  Created by Peter Shih on 7/12/11.
//  Copyright 2011 Seven Minute Labs. All rights reserved.
//

#import "SearchTermController.h"
#import "PSSearchCenter.h"

@implementation SearchTermController

@synthesize delegate = _delegate;

- (id)initWithContainer:(NSString *)container {
  self = [super init];
  if (self) {
    _container = [container copy];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
  RELEASE_SAFELY(_dismissGesture);
  [super dealloc];
}

#pragma mark - View Config
- (UIView *)backgroundView {
  UIImageView *bg = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bg_darkwood.jpg"]] autorelease];
  bg.frame = self.view.bounds;
  bg.autoresizingMask = ~UIViewAutoresizingNone;
  return bg;
}

#pragma mark - View
- (void)loadView {
  [super loadView];
  
  // Nullview
  [_nullView setLoadingTitle:@"Searching" loadingSubtitle:@"Finding Restaurants" emptyTitle:@"Epic Fail" emptySubtitle:@"FFFFFUUUUUUUU" image:nil];
  
  [self setupTableViewWithFrame:self.view.bounds andStyle:UITableViewStylePlain andSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
  
  self.tableView.scrollsToTop = NO;
  
  _dismissGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelSearch)];
  [_nullView addGestureRecognizer:_dismissGesture];
  _dismissGesture.enabled = YES;
  
  // Populate datasource
  [self loadDataSource];
  
}

- (void)loadDataSource {
  [super loadDataSource];
  [self.items removeAllObjects];
  
  // Always show "Current Location"
  if ([_container isEqual:@"where"]) {
    [self.items addObject:[NSArray arrayWithObject:@"Current Location"]];
  } else {
    [self.items addObject:[NSArray array]];
  }
  
  // Stub for search results
  [self.items addObject:[NSArray array]];
  
  [self dataSourceDidLoad];
}

- (void)dataSourceDidLoad {
  [self.tableView reloadData];
  [super dataSourceDidLoad];
}

- (BOOL)shouldLoadMore {
  return NO;
}

#pragma mark - Setup
- (void)setupTableFooter {
  UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)] autorelease];
  _tableView.tableFooterView = footerView;
}

- (void)cancelSearch {
  if (self.delegate && [self.delegate respondsToSelector:@selector(cancelSearch)]) {
    [self.delegate searchCancelled];
  }
}

#pragma mark - Search
- (void)searchWithTerm:(NSString *)term {
  NSArray *filteredArray = [[PSSearchCenter defaultCenter] searchResultsForTerm:term inContainer:_container];

  if ([filteredArray count] > 0) {
    _dismissGesture.enabled = NO;
  } else {
    _dismissGesture.enabled = YES;
  }
  [self.items replaceObjectAtIndex:1 withObject:filteredArray];
  [self dataSourceDidLoad];
}

#pragma mark - Table
//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//  if (section == 0) return nil;
//  
//  UIView *sectionHeaderView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 26)] autorelease];
////  sectionHeaderView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg_table_header.png"]];
//  sectionHeaderView.backgroundColor = SECTION_HEADER_COLOR;
//  
//  UILabel *sectionHeaderLabel = [[[UILabel alloc] initWithFrame:CGRectMake(5, 0, 310, 24)] autorelease];
//  sectionHeaderLabel.backgroundColor = [UIColor clearColor];
//  sectionHeaderLabel.text = @"Previously Searched...";
//  sectionHeaderLabel.textColor = [UIColor whiteColor];
//  sectionHeaderLabel.shadowColor = [UIColor blackColor];
//  sectionHeaderLabel.shadowOffset = CGSizeMake(0, 1);
//  sectionHeaderLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:12.0];
//  [sectionHeaderView addSubview:sectionHeaderLabel];
//  
//  return sectionHeaderView;
//}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView.style == UITableViewStylePlain) {
    UIView *backgroundView = [[UIView alloc] initWithFrame:cell.bounds];
    backgroundView.backgroundColor = LIGHT_GRAY;
    cell.backgroundView = backgroundView;
    
    UIView *selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
    selectedBackgroundView.backgroundColor = CELL_SELECTED_COLOR;
    cell.selectedBackgroundView = selectedBackgroundView;
    
    [backgroundView release];
    [selectedBackgroundView release];
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = nil;
  NSString *reuseIdentifier = @"searchTermCell";
  
  cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier] autorelease];
  }
  
  NSString *term = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
  
  cell.textLabel.text = term;
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  NSString *term = [[self.items objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
  
  // Search term selected
  if (self.delegate && [self.delegate respondsToSelector:@selector(searchTermSelected:inContainer:)]) {
    [self.delegate searchTermSelected:term inContainer:_container];
  }
}

#pragma mark UIKeyboard
- (void)keyboardWillShow:(NSNotification *)aNotification {
  [self moveTextViewForKeyboard:aNotification up:YES];
}

- (void)keyboardWillHide:(NSNotification *)aNotification {
  [self moveTextViewForKeyboard:aNotification up:NO]; 
}

- (void)moveTextViewForKeyboard:(NSNotification*)aNotification up:(BOOL)up {
  NSDictionary* userInfo = [aNotification userInfo];
  
  // Get animation info from userInfo
  NSTimeInterval animationDuration;
  UIViewAnimationCurve animationCurve;
  
  CGRect keyboardEndFrame;
  
  [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
  [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
  
  
  CGRect keyboardFrame = CGRectZero;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 30200
  // code for iOS below 3.2
  [[userInfo objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardEndFrame];
  keyboardFrame = keyboardEndFrame;
#else
  // code for iOS 3.2 ++
  [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
  keyboardFrame = [UIScreen convertRect:keyboardEndFrame toView:self.view];
#endif  
  
  // Animate up or down
  NSString *dir = up ? @"up" : @"down";
  [UIView beginAnimations:dir context:nil];
  [UIView setAnimationDuration:animationDuration];
  [UIView setAnimationCurve:animationCurve];
  
  if (up) {
    self.view.height = self.view.height - keyboardFrame.size.height;
  } else {
    self.view.height = self.view.height + keyboardFrame.size.height;
  }
  
  [UIView commitAnimations];
}

@end
