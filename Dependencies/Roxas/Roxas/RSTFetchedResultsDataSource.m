//
//  RSTFetchedResultsDataSource.m
//  Roxas
//
//  Created by Riley Testut on 8/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "RSTFetchedResultsDataSource.h"
#import "RSTCellContentDataSource_Subclasses.h"

#import "RSTBlockOperation.h"
#import "RSTSearchController.h"

#import "RSTHelperFile.h"


static void *RSTFetchedResultsDataSourceContext = &RSTFetchedResultsDataSourceContext;


NS_ASSUME_NONNULL_BEGIN

// Declare custom NSPredicate subclass so we can detect whether NSFetchedResultsController's predicate was changed externally or by us.
@interface RSTProxyPredicate : NSCompoundPredicate

- (instancetype)initWithPredicate:(nullable NSPredicate *)predicate externalPredicate:(nullable NSPredicate *)externalPredicate;

@end

NS_ASSUME_NONNULL_END


@implementation RSTProxyPredicate

//- (instancetype)initWithPredicate:(nullable NSPredicate *)predicate externalPredicate:(nullable NSPredicate *)externalPredicate
//{
//    NSMutableArray *subpredicates = [NSMutableArray array];
//    
//    if (externalPredicate != nil)
//    {
//        [subpredicates addObject:externalPredicate];
//    }
//    
//    if (predicate != nil)
//    {
//        [subpredicates addObject:predicate];
//    }
//    
//    self = [super initWithType:NSAndPredicateType subpredicates:subpredicates];
//    return self;
//}

- (instancetype)initWithPredicate:(nullable NSPredicate *)predicate externalPredicate:(nullable NSPredicate *)externalPredicate
{
    NSMutableArray *subpredicates = [NSMutableArray array];
    
    // 仅添加非nil且合法的谓词
    if (externalPredicate != nil && [self isPredicateValid:externalPredicate]) {
        [subpredicates addObject:externalPredicate];
    }
    if (predicate != nil && [self isPredicateValid:predicate]) {
        [subpredicates addObject:predicate];
    }
    
    // 若没有有效谓词，使用“匹配所有”的安全谓词
    if (subpredicates.count == 0) {
        self = [super initWithType:NSAndPredicateType subpredicates:@[[NSPredicate predicateWithValue:YES]]];
    } else {
        self = [super initWithType:NSAndPredicateType subpredicates:subpredicates];
    }
    return self;
}

// 校验谓词是否合法（例如不包含nil参数）
- (BOOL)isPredicateValid:(NSPredicate *)predicate
{
    // 简单实现：检查谓词是否为nil，或是否包含非法参数（可根据实际场景扩展）
    if (predicate == nil) return NO;
    
    // 更严格的校验：解析谓词表达式，检查是否有nil常量（示例逻辑）
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)predicate;
        if (comparisonPredicate.rightExpression.constantValue == nil) {
            return NO; // 右侧值为nil，非法
        }
    }
    return YES;
}

@end


NS_ASSUME_NONNULL_BEGIN

@interface RSTFetchedResultsDataSource ()

@property (nonatomic, copy, nullable) NSPredicate *externalPredicate;

@property (nonatomic, copy) BOOL (^predicateValidationHandler)(NSPredicate *predicate);

// 添加方法声明
- (BOOL)isPredicateValid:(NSPredicate *)predicate;

@end

NS_ASSUME_NONNULL_END


@implementation RSTFetchedResultsDataSource

- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetchRequest managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    self = [self initWithFetchedResultsController:fetchedResultsController];
    return self;
}

- (instancetype)initWithFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
{
    self = [super init];
    if (self)
    {
        [self setFetchedResultsController:fetchedResultsController];
        
        __weak RSTFetchedResultsDataSource *weakSelf = self;
        self.defaultSearchHandler = ^NSOperation *(RSTSearchValue *searchValue, RSTSearchValue *previousSearchValue) {
            return [RSTBlockOperation blockOperationWithExecutionBlock:^(RSTBlockOperation * _Nonnull __weak operation) {
                [weakSelf setPredicate:searchValue.predicate refreshContent:NO];
                
                // Only refresh content if search operation has not been cancelled, such as when the search text changes.
                if (operation != nil && ![operation isCancelled])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.contentView reloadData];
                    });
                }
            }];
        };
    }
    
    return self;
}

- (void)dealloc
{
    [_fetchedResultsController removeObserver:self forKeyPath:@"fetchRequest.predicate" context:RSTFetchedResultsDataSourceContext];
}

#pragma mark - RSTCellContentViewDataSource -

- (id)itemAtIndexPath:(NSIndexPath *)indexPath
{
    id item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return item;
}

- (NSInteger)numberOfSectionsInContentView:(__kindof UIView<RSTCellContentView> *)contentView
{
    if (self.fetchedResultsController.sections == nil)
    {
        NSError *error = nil;
        if (![self.fetchedResultsController performFetch:&error])
        {
            ELog(error);
        }
    }
    
    NSInteger numberOfSections = self.fetchedResultsController.sections.count;
    return numberOfSections;
}

- (NSInteger)contentView:(__kindof UIView<RSTCellContentView> *)contentView numberOfItemsInSection:(NSInteger)section
{
    id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    
    if (self.liveFetchLimit == 0)
    {
        return sectionInfo.numberOfObjects;
    }
    else
    {
        return MIN(sectionInfo.numberOfObjects, self.liveFetchLimit);
    }
}

//- (void)filterContentWithPredicate:(nullable NSPredicate *)predicate
//{
//    RSTProxyPredicate *proxyPredicate = [[RSTProxyPredicate alloc] initWithPredicate:predicate externalPredicate:self.externalPredicate];
//    self.fetchedResultsController.fetchRequest.predicate = proxyPredicate;
//    
//    NSError *error = nil;
//    if (![self.fetchedResultsController performFetch:&error])
//    {
//        ELog(error);
//    }
//}

- (void)filterContentWithPredicate:(nullable NSPredicate *)predicate
{
    // 强制使用安全谓词
//    NSPredicate *safePredicate = [PredicateSafetyChecker safePredicateFrom:predicate];
    
//    self.fetchedResultsController.fetchRequest.predicate = safePredicate;
    
    // 先使用内部默认校验
    BOOL isPredicateValid = [self isPredicateValid:predicate];
    // 若上层提供了自定义校验，覆盖结果
    if (self.predicateValidationHandler) {
        isPredicateValid = self.predicateValidationHandler(predicate);
    }
    
    // 使用校验后的谓词
    NSPredicate *safePredicate = isPredicateValid ? predicate : [NSPredicate predicateWithValue:YES];
    RSTProxyPredicate *proxyPredicate = [[RSTProxyPredicate alloc] initWithPredicate:safePredicate externalPredicate:self.externalPredicate];

    NSError *error;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"CoreData fetch error: %@", error);
    }
}

#pragma mark - KVO -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context != RSTFetchedResultsDataSourceContext)
    {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    NSPredicate *predicate = change[NSKeyValueChangeNewKey];
    if (![predicate isKindOfClass:[RSTProxyPredicate class]])
    {
        self.externalPredicate = predicate;
        
        RSTProxyPredicate *proxyPredicate = [[RSTProxyPredicate alloc] initWithPredicate:self.predicate externalPredicate:self.externalPredicate];

        
        [[(NSFetchedResultsController *)object fetchRequest] setPredicate:proxyPredicate];
    }
}

#pragma mark - <NSFetchedResultsControllerDelegate> -

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.contentView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    RSTCellContentChangeType changeType = RSTCellContentChangeTypeFromFetchedResultsChangeType(type);
    
    RSTCellContentChange *change = [[RSTCellContentChange alloc] initWithType:changeType sectionIndex:sectionIndex];
    change.rowAnimation = self.rowAnimation;
    [self addChange:change];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    RSTCellContentChangeType changeType = RSTCellContentChangeTypeFromFetchedResultsChangeType(type);
    
    RSTCellContentChange *change = nil;
    
    if (type == NSFetchedResultsChangeUpdate && ![indexPath isEqual:newIndexPath])
    {
        // Sometimes NSFetchedResultsController incorrectly reports moves as updates with different index paths.
        // This can cause assertion failures and strange UI issues.
        // To compensate, we manually check for these "updates" and turn them into moves.
        change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeMove currentIndexPath:indexPath destinationIndexPath:newIndexPath];
    }
    else
    {
        change = [[RSTCellContentChange alloc] initWithType:changeType currentIndexPath:indexPath destinationIndexPath:newIndexPath];
    }

    change.rowAnimation = self.rowAnimation;
    
    if (self.liveFetchLimit > 0)
    {
        NSInteger itemCount = self.itemCount;
        
        switch (change.type)
        {
            case RSTCellContentChangeInsert:
                if (newIndexPath.item >= self.liveFetchLimit)
                {
                    return;
                }
                
                break;
                
            case RSTCellContentChangeDelete:
                if (indexPath.item >= self.liveFetchLimit)
                {
                    return;
                }
                
                if (itemCount >= self.liveFetchLimit)
                {
                    // Unlike insertions, deletions don't also report the items that moved.
                    // To ensure consistency, we manually insert an item previously hidden by fetch limit.
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.liveFetchLimit - 1 inSection:0];

                    RSTCellContentChange *change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeInsert currentIndexPath:nil destinationIndexPath:indexPath];
                    [self.contentView addChange:change];
                }
                
                break;
                
            case RSTCellContentChangeUpdate:
                if (indexPath.item >= self.liveFetchLimit)
                {
                    return;
                }
                
                break;
                
            case RSTCellContentChangeMove:
                if (indexPath.item >= self.liveFetchLimit && newIndexPath.item >= self.liveFetchLimit)
                {
                    return;
                }
                else if (indexPath.item >= self.liveFetchLimit && newIndexPath.item < self.liveFetchLimit)
                {
                    change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeInsert currentIndexPath:nil destinationIndexPath:newIndexPath];
                }
                else if (indexPath.item < self.liveFetchLimit && newIndexPath.item >= self.liveFetchLimit)
                {
                    change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeDelete currentIndexPath:indexPath destinationIndexPath:nil];
                }
                
                break;
        }
    }
    
    [self addChange:change];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.contentView endUpdates];
}

#pragma mark - Getters/Setters -

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == _fetchedResultsController)
    {
        return;
    }
    
    // Clean up previous _fetchedResultsController.
    [_fetchedResultsController removeObserver:self forKeyPath:@"fetchRequest.predicate" context:RSTFetchedResultsDataSourceContext];
    
    _fetchedResultsController.fetchRequest.predicate = self.externalPredicate;
    self.externalPredicate = nil;
    
    
    // Prepare new _fetchedResultsController.
    _fetchedResultsController = fetchedResultsController;
    
    if (_fetchedResultsController.delegate == nil)
    {
        _fetchedResultsController.delegate = self;
    }
    
    self.externalPredicate = _fetchedResultsController.fetchRequest.predicate;
    
    RSTProxyPredicate *proxyPredicate = [[RSTProxyPredicate alloc] initWithPredicate:self.predicate externalPredicate:self.externalPredicate];
    _fetchedResultsController.fetchRequest.predicate = proxyPredicate;
    
    [_fetchedResultsController addObserver:self forKeyPath:@"fetchRequest.predicate" options:NSKeyValueObservingOptionNew context:RSTFetchedResultsDataSourceContext];
    
    rst_dispatch_sync_on_main_thread(^{
        [self.contentView reloadData];
    });
}

- (void)setLiveFetchLimit:(NSInteger)liveFetchLimit
{
    if (liveFetchLimit == _liveFetchLimit)
    {
        return;
    }
    
    NSInteger previousLiveFetchLimit = _liveFetchLimit;
    _liveFetchLimit = liveFetchLimit;
    
    // Turn 0 -> NSIntegerMax to simplify calculations.
    if (liveFetchLimit == 0)
    {
        liveFetchLimit = NSIntegerMax;
    }
    
    if (previousLiveFetchLimit == 0)
    {
        previousLiveFetchLimit = NSIntegerMax;
    }
    
    [self.contentView beginUpdates];
    
    id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections.firstObject;
    NSInteger itemCount = sectionInfo.numberOfObjects;
    
    if (liveFetchLimit > previousLiveFetchLimit)
    {
        for (NSInteger i = previousLiveFetchLimit; i < itemCount; i++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
                        
            RSTCellContentChange *change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeInsert currentIndexPath:nil destinationIndexPath:indexPath];
            [self addChange:change];
        }
    }
    else
    {
        for (NSInteger i = liveFetchLimit; i < itemCount && i < previousLiveFetchLimit; i++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
            
            RSTCellContentChange *change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeDelete currentIndexPath:indexPath destinationIndexPath:nil];
            [self addChange:change];
        }
    }
    
    [self.contentView endUpdates];
}

- (NSInteger)itemCount
{
    if (self.fetchedResultsController.fetchedObjects == nil)
    {
        return [super itemCount];
    }
    
    NSUInteger itemCount = self.fetchedResultsController.fetchedObjects.count;
    return itemCount;
}

// 实现谓词校验方法
- (BOOL)isPredicateValid:(NSPredicate *)predicate
{
    // 复用 RSTProxyPredicate 中的校验逻辑
    if (predicate == nil) return NO;
    
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *comparisonPredicate = (NSComparisonPredicate *)predicate;
        if (comparisonPredicate.rightExpression.constantValue == nil) {
            return NO; // 右侧值为nil，非法
        }
    }
    return YES;
}

@end

@implementation RSTFetchedResultsTableViewDataSource
@end

@implementation RSTFetchedResultsCollectionViewDataSource
@end

@implementation RSTFetchedResultsPrefetchingDataSource
@dynamic prefetchItemCache;
@dynamic prefetchHandler;
@dynamic prefetchCompletionHandler;

- (BOOL)isPrefetchingDataSource
{
    return YES;
}

@end

@implementation RSTFetchedResultsTableViewPrefetchingDataSource
@end

@implementation RSTFetchedResultsCollectionViewPrefetchingDataSource
@end
