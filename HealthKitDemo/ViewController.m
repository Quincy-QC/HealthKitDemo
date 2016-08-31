//
//  ViewController.m
//  HealthKitDemo
//
//  Created by UntilYou-QC on 16/8/30.
//  Copyright © 2016年 UntilYou-QC. All rights reserved.
//

#import "ViewController.h"
#import <HealthKit/HealthKit.h>

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableV;
@property (nonatomic, strong) HKHealthStore *healthStore;
@property (nonatomic, strong) NSMutableDictionary *healthInfo;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableV.delegate = self;
    self.tableV.dataSource = self;
    [self.tableV registerClass:[UITableViewCell class] forCellReuseIdentifier:@"reuse"];
    
}

// 获取“健康”的数据
- (IBAction)getHealthInfo:(UIBarButtonItem *)sender {
    
    // 查看 HealthKit 在设备上是否可用，ipad 不支持 HealthKit
    if (![HKHealthStore isHealthDataAvailable]) {
        NSLog(@"设备暂不支持 HealthKit");
        return;
    }
    
    if ([UIDevice currentDevice].systemVersion.doubleValue < 8.0) {
        NSLog(@"IOS8.0 以下暂不支持 HealthKit");
        return;
    }
    
    // 创建 HealthKit
    self.healthStore = [[HKHealthStore alloc] init];
    
    // 设置需要获取的权限
    HKObjectType *stepCount = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
//    HKQuantityType *heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
//    HKQuantityType *weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
//    HKQuantityType *temperatureType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyTemperature];
//    HKCharacteristicType *birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
//    HKCharacteristicType *sexType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
//    HKQuantityType *stepCountType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
//    HKQuantityType *activeEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
//    HKObjectType *stepCount2 = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    NSSet *healthSet = [NSSet setWithObjects:stepCount, nil];
    
    // 从"健康"中获取权限
    /*!
     *  第一个参数:想要写入的数据类型
     *  第二个参数:想要读取的数据类型
     */
    [self.healthStore requestAuthorizationToShareTypes:nil readTypes:healthSet completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"获取权限'健康'成功");
            [self readHealthData];
        } else {
            NSLog(@"获取'健康'权限失败 error:%@", error);
        }
    }];
}

- (void)readHealthData {
    
    // HKQuantityType 是 HKSampleType 的子类, HKSampleType 是 HKObjectType 的子类
    HKSampleType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    // 设置谓词
    NSPredicate *predicate = [self predicateForSamplesToday];
    
    // 查询数据
    HKSampleQuery *sampleQuery = [[HKSampleQuery alloc] initWithSampleType:sampleType predicate:predicate limit:HKObjectQueryNoLimit sortDescriptors:nil resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        if (!results) {
            NSLog(@"查询失败, error:%@", error);
        } else {
            NSLog(@"查询数据:%ld ------ result:%@", results.count, results);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSInteger totalSteps = 0;
                
                NSString *tempTime = @"";
                
                for (HKQuantitySample *quantitySample in results) {
                    
                    if (![tempTime isEqualToString:[self getTimeWithQuantitySample:quantitySample]]) {
                        
                        tempTime = [self getTimeWithQuantitySample:quantitySample];
                        totalSteps = 0;
                    }
                    
                    // HKQuantity 存储了给定单位的值。之后你可以用任何兼容的单位来取值
                    HKQuantity *quantity = quantitySample.quantity;
                    NSLog(@"==========%@", quantity);
                    
                    // UIKit 提供了便捷方法来创建HealthKit支持的所有基本单位。它还提供了构建复合单位需要的数学运算
                    double userHeight = [quantity doubleValueForUnit:[HKUnit countUnit]];
                    totalSteps += userHeight;
                    
                    [self.healthInfo setValue:@(totalSteps) forKey:tempTime];
                }
                
                NSLog(@"当天行走总路程:%ld", totalSteps);
                
                [self.tableV reloadData];
            });
            
        }
    }];
    
    // 执行查询
    [self.healthStore executeQuery:sampleQuery];
}

// 设置查询谓词
// 获取当天健康信息
- (NSPredicate *)predicateForSamplesToday {
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    // 获取前几天的时间
//    components.day = -7;
    
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:3 toDate:startDate options:0];
    NSLog(@"startDate----%@, endDate-----%@", startDate, endDate);
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionNone];
    
    return predicate;
}

// 获取时间
- (NSString *)getTimeWithQuantitySample:(HKQuantitySample *)quantitySample {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"YYYY.MM.dd";
    NSString *dateString = [dateFormatter stringFromDate:quantitySample.endDate];
    NSLog(@"时间======= %@", dateString);
    return dateString;
}

#pragma mark ----- UITableViewDelegate -----
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.healthInfo.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuse" forIndexPath:indexPath];
    
    // 对时间进行排序
    NSMutableArray *array = [self.healthInfo.allKeys mutableCopy];
    [array sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];
    
    cell.textLabel.text = [NSString stringWithFormat:@"时间:%@  步数:%@", array[indexPath.row], self.healthInfo[array[indexPath.row]]];
    return cell;
}

- (NSMutableDictionary *)healthInfo {
    if (!_healthInfo) {
        _healthInfo = [NSMutableDictionary dictionary];
    }
    return _healthInfo;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
