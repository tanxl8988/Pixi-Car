//
//  APKLocalAlbumViewController.m
//  微米
//
//  Created by Mac on 17/4/10.
//  Copyright © 2017年 APK. All rights reserved.
//

#import "APKLocalAlbumViewController.h"
#import "APKLocalFileCell.h"
#import <Photos/Photos.h>
#import "MBProgressHUD.h"
#import "MWPhotoBrowser.h"
#import "APKMWPhoto.h"
#import "APKLocalFile.h"
#import "APKRetrieveLocalFileListing.h"
#import "APKCachingAssetThumbnail.h"
#import "APKMOCManager.h"
#import "APKVideoPlayer.h"
#import "APKPlayerViewController.h"


@interface APKLocalAlbumViewController ()<UITableViewDataSource,UITableViewDelegate,MWPhotoBrowserDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *openButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UILabel *tipsLabel;
@property (strong,nonatomic) NSMutableArray *photos;
@property (strong,nonatomic) APKRetrieveLocalFileListing *retrieveFileListing;
@property (strong,nonatomic) NSMutableArray *dataSource;
@property (nonatomic) BOOL isLoadingData;
@property (nonatomic) BOOL isNoMoreData;
@property (strong,nonatomic) APKCachingAssetThumbnail *cachingThumbnail;
@property (nonatomic) CGSize imagevSize;

@end

@implementation APKLocalAlbumViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.navigationItem.title = NSLocalizedString(@"Pixi Car", nil);
    self.titleLabel.text = NSLocalizedString(@"本地文件", nil);
    [self.cancelButton setTitle:NSLocalizedString(@"取消", nil) forState:UIControlStateNormal];
    self.tipsLabel.text = nil;
    [self updateSelectInfo];
//    self.deleteButton.layer.shadowOffset = CGSizeMake(0, 2);
//    self.deleteButton.layer.shadowOpacity = 0.80;
//    self.openButton.layer.shadowOffset = CGSizeMake(0, 2);
//    self.openButton.layer.shadowOpacity = 0.80;
    
    self.tableView.editing = YES;
    CGFloat rowHeight = 101;
    self.tableView.rowHeight = rowHeight;
    self.imagevSize = CGSizeMake(rowHeight - 40,rowHeight - 40);
    
    [self retrieveData];
}

#pragma mark - event response


- (IBAction)clickOpenButton:(UIButton *)sender {
    
    NSMutableArray *photoArray = [[NSMutableArray alloc] init];
    NSMutableArray *videoArray = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        
        APKLocalFile *file = self.dataSource[indexPath.row];
        if (file.info.type == APKFileTypeCapture) {
            [photoArray addObject:file];
        }else{
            [videoArray addObject:file];
        }
    }
    
    //浏览选择多的文件类型
    if (photoArray.count >= videoArray.count) {
        
        [self.photos removeAllObjects];
        for (APKLocalFile *file in photoArray) {
            
            APKMWPhoto *photo = [APKMWPhoto photoWithAsset:file.asset targetSize:CGSizeMake(file.asset.pixelWidth, file.asset.pixelHeight)];
            [self.photos addObject:photo];
        }
        
        MWPhotoBrowser *photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
        photoBrowser.alwaysShowControls = YES;
        photoBrowser.displayActionButton = NO;
        UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:photoBrowser];
        [self presentViewController:navi animated:YES completion:nil];
        
    }else{
        
        NSMutableArray *assetArray = [[NSMutableArray alloc] init];
        NSMutableArray *nameArray = [[NSMutableArray alloc] init];
        for (APKLocalFile *file in videoArray) {
            
            [assetArray addObject:file.asset];
            [nameArray addObject:file.info.name];
        }
        
        APKPlayerViewController *playVC = [[APKPlayerViewController alloc] init];
        playVC.URL = assetArray.firstObject;
        [playVC configureWithURLs:assetArray currentIndex:0 fileArray:self.dataSource];
        playVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:playVC animated:YES completion:nil];
        return;
        
        APKVideoPlayer *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"APKVideoPlayer"];
        [vc configureWithAssetArray:assetArray nameArray:nameArray currentIndex:0];
        [self presentViewController:vc animated:YES completion:nil];
    }
}

- (IBAction)clickDeleteButton:(UIButton *)sender {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        
        APKLocalFile *file = self.dataSource[indexPath.row];
        [assets addObject:file.asset];
        [files addObject:file];
    }
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        [PHAssetChangeRequest deleteAssets:assets];
        
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (success) {
                
                NSManagedObjectContext *context = [APKMOCManager sharedInstance].context;
                for (APKLocalFile *file in files) {
                    
                    [context deleteObject:file.info];
                }
                [context save:nil];
                
                [self.dataSource removeObjectsInArray:files];
                [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationAutomatic];
                
                [self clickCancelButton:self.cancelButton];
            }
            
            [hud hide:YES];
        });
    }];
}

- (IBAction)clickCancelButton:(UIButton *)sender {
    
    [self.tableView reloadData];
    [self updateSelectInfo];
}

#pragma mark - private method

- (void)retrieveData{
    
    self.isLoadingData = YES;
    
    __weak typeof(self)weakSelf = self;
    [self.retrieveFileListing executeWithOffset:self.dataSource.count count:10 completionHandler:^(NSArray<APKLocalFile *> *fileArray, NSArray<PHAsset *> *assets) {
        
        if (fileArray.count > 0) {
            
            NSMutableArray *indexPathArray = [[NSMutableArray alloc] init];
            for (NSInteger row = weakSelf.dataSource.count; row < weakSelf.dataSource.count + fileArray.count; row++) {
                
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
                [indexPathArray addObject:indexPath];
            }
            [weakSelf.dataSource addObjectsFromArray:fileArray];
            [weakSelf.tableView insertRowsAtIndexPaths:indexPathArray withRowAnimation:UITableViewRowAnimationAutomatic];
            
            [weakSelf.cachingThumbnail executeWithAssets:assets];
        }
        
        weakSelf.isLoadingData = NO;
        weakSelf.isNoMoreData = fileArray.count == 0 ? YES : NO;
    }];
}

- (void)updateSelectInfo{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSInteger count = self.tableView.indexPathsForSelectedRows.count;
        if (count == 0) {
            
            self.cancelButton.hidden = YES;
            self.openButton.enabled = NO;
            self.deleteButton.enabled = NO;
            
        }else{
            
            self.cancelButton.hidden = NO;
            self.openButton.enabled = count == 1;
            self.deleteButton.enabled = YES;
        }
    });
}

#pragma mark - MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser{
    
    return self.photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index{
    
    MWPhoto *photo = self.photos[index];
    return photo;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellIdentifier = @"localFileCell";
    APKLocalFileCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    APKLocalFile *file = self.dataSource[indexPath.row];
    cell.label.text = file.info.name;
    [self.cachingThumbnail requestThumbnailForAsset:file.asset completionHandler:^(UIImage *thumbnail) {
       
        cell.imagev.image = thumbnail;
    }];
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self updateSelectInfo];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self updateSelectInfo];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if (!self.isNoMoreData && !self.isLoadingData) {
        
        CGFloat x = 0;//x是触发操作的阀值
        if (scrollView.contentOffset.y >= fmaxf(.0f, scrollView.contentSize.height - scrollView.frame.size.height) + x)
        {
            [self retrieveData];
        }
    }
}

#pragma mark - getter

- (APKCachingAssetThumbnail *)cachingThumbnail{
    
    if (!_cachingThumbnail) {
        
        _cachingThumbnail = [[APKCachingAssetThumbnail alloc] initWithSize:self.imagevSize contentMode:PHImageContentModeDefault options:nil];
    }
    
    return _cachingThumbnail;
}

- (NSMutableArray *)dataSource{
    
    if (!_dataSource) {
        
        _dataSource = [[NSMutableArray alloc] init];
    }
    
    return _dataSource;
}

- (APKRetrieveLocalFileListing *)retrieveFileListing{
    
    if (!_retrieveFileListing) {
        
        _retrieveFileListing = [[APKRetrieveLocalFileListing alloc] init];
    }
    
    return _retrieveFileListing;
}

- (NSMutableArray *)photos{
    
    if (!_photos) {
        _photos = [[NSMutableArray alloc] init];
    }
    return _photos;
}

@end
