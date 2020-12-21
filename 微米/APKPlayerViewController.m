//
//  APKPlayerViewController.m
//  万能AIT
//
//  Created by mac on 2020/8/8.
//  Copyright © 2020 APK. All rights reserved.
//

#import "APKPlayerViewController.h"
#import "MobileVLCKit/VLCMediaPlayer.h"
#import "APKAlertTool.h"
#import "APKLocalFile.h"

@interface APKPlayerViewController ()<VLCMediaPlayerDelegate,VLCMediaDelegate>
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (weak, nonatomic) IBOutlet UIButton *previousButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *flower;
@property (strong,nonatomic) VLCMediaPlayer *player;
@property (nonatomic) NSInteger currentIndex;
@property (strong,nonatomic) NSArray *URLs;
@property (strong,nonatomic) VLCMediaPlayer *mediaPlayer;
@property (nonatomic) BOOL haveLoadVideoDuration;
@property (nonatomic) BOOL isStopForLoadNewVideo;
@property (nonatomic,assign) int lastPLayTime;
@property (nonatomic,retain) NSURL *localFileURL;
@property (nonatomic,retain) NSArray *localFileArr;


@end

@implementation APKPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateNormal];
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateSelected];
    
    [self updateSwitchVideoButtons];
    
    self.mediaPlayer.drawable = self.playerView;
    
    if (self.URLs.count > self.currentIndex) {
           
           [self getFileName];
            [self loadNewVideo];
    }
    
//    NSString *caching = [NSString stringWithFormat:@"--network-caching=%d",3000];
//    NSString *jitter = [NSString stringWithFormat:@"--clock-jitter=%d",3000];
//    NSArray *options = @[caching,jitter,@"--extraintf="];
//    VLCMediaPlayer *player = [[VLCMediaPlayer alloc] initWithOptions:nil];
//    self.player = player;
//    self.player.media = [VLCMedia mediaWithURL:self.URL];
//    self.player.drawable = self.playerView;
//    self.player.delegate = self;
//    [self.player play];
    
    // Do any additional setup after loading the view from its nib.
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.mediaPlayer stop];

    [self.mediaPlayer removeObserver:self forKeyPath:@"state"];
}

- (void)configureWithURLs:(NSArray *)URLs currentIndex:(NSInteger)currentIndex fileArray:(NSArray *)fileArray
{

    self.URLs = URLs;
    self.currentIndex = currentIndex;
    self.localFileArr = fileArray;
}

- (IBAction)back:(UIButton *)sender {
    
    if (self.mediaPlayer.state != VLCMediaPlayerStateStopped) {
          
          [self.mediaPlayer stop];
      }

      [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    
    if ([keyPath isEqualToString:@"state"]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            VLCMediaPlayerState state = [change[@"new"] integerValue];
            [weakSelf updatePlayPauseButtonWithState:state];
            [weakSelf updateTipsLabelWithState:state];
            [weakSelf updateFlowerWithState:state];
            [weakSelf updateProgressInfoWithState:state];
//            NSLog(@"=============new state:%ld",(long)state);
            
            if (state == VLCMediaPlayerStateStopped && weakSelf.isStopForLoadNewVideo) {
                
                weakSelf.isStopForLoadNewVideo = NO;
                [weakSelf loadNewVideo];
            }
        });
    }
}

- (void)loadNewVideo{
    
    if (self.mediaPlayer.state != VLCMediaPlayerStateStopped) {
        
        self.isStopForLoadNewVideo = YES;
//        self.playFinished = NO;
        [self.mediaPlayer stop];
        return;
    }
    
    self.haveLoadVideoDuration = NO;
    NSURL *url = nil;
    if ([self.URLs.firstObject class] == [PHAsset class]) {

        if (!self.localFileURL || self.localFileURL == nil) {
            [self getVideoURL:self.URLs[self.currentIndex]];
            return;
        }else
            url = self.localFileURL;

    }else if ([self.URLs.firstObject class] == [NSURL class])
        url = self.URLs[self.currentIndex];
    
    VLCMedia *media = [VLCMedia mediaWithURL:url];
    media.delegate = self;
    [self.mediaPlayer setMedia:media];
    [self.mediaPlayer play];
}

-(void)getVideoURL:(PHAsset *)asset
{
    __weak typeof(self) weakSelf = self;
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    
    PHImageManager *manager = [PHImageManager defaultManager];
    [manager requestAVAssetForVideo:asset
                            options:options
                      resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                          // asset 类型为 AVURLAsset  为此资源的fileURL
                          // <AVURLAsset: 0x283386e60, URL = file:///var/mobile/Media/DCIM/100APPLE/IMG_0049.MOV>
                          AVURLAsset *urlAsset = (AVURLAsset *)asset;
                          // 视频数据
                          NSURL *url = urlAsset.URL;
                          weakSelf.localFileURL = url;
                          [weakSelf loadNewVideo];
                          NSData *vedioData = [NSData dataWithContentsOfURL:urlAsset.URL];
                          NSLog(@"%@",vedioData);
    }];
}

- (void)updateProgress:(int)currentSeconds{
    
    if (!self.haveLoadVideoDuration) {
        
        self.haveLoadVideoDuration = YES;
        VLCMedia *media = self.mediaPlayer.media;
        int totalSeconds = media.length.intValue / 1000;
        self.progressSlider.maximumValue = totalSeconds;
        self.progressSlider.minimumValue = 0;
        int seconds = totalSeconds % 60;
        int minutes = totalSeconds / 60;
        NSString *durationInfo = [NSString stringWithFormat:@"%d:%02d",minutes,seconds];
        self.durationLabel.text = durationInfo;
    }
    
    self.progressSlider.value = currentSeconds;
    
    int seconds = currentSeconds % 60;
    int minutes = currentSeconds / 60;
    NSString *progressInfo = [NSString stringWithFormat:@"%d:%02d",minutes,seconds];
    self.progressLabel.text = progressInfo;
}

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification{
    
    if (self.flower.isAnimating) {
        
        [self.flower stopAnimating];
    }
    
    int currentSeconds = self.mediaPlayer.time.intValue / 1000;
    
//    NSLog(@"----->%d",currentSeconds);
//    VLCMedia *media = self.mediaPlayer.media;
//    NSLog(@"media length:%d",media.length.intValue);
//    NSLog(@"media player time:%d",self.mediaPlayer.time.intValue);
    
    [self updateProgress:currentSeconds];
}

- (void)updateProgressInfoWithState:(VLCMediaPlayerState)state{
    
    switch (state) {
        case VLCMediaPlayerStateEnded:
        case VLCMediaPlayerStateError:
        case VLCMediaPlayerStateStopped:
            self.durationLabel.text = @"00:00";
            self.progressLabel.text = @"00:00";
            self.progressSlider.value = 0;
            break;
            
        default:
            break;
    }
}

- (void)updateFlowerWithState:(VLCMediaPlayerState)state{
    
    if (state == VLCMediaPlayerStateBuffering || state == VLCMediaPlayerStateOpening) {
        
        if (!self.flower.isAnimating) {
            [self.flower startAnimating];
        }
    }
    else{
        
        if (self.flower.isAnimating) {
            [self.flower stopAnimating];
        }
    }
}

- (void)updateTipsLabelWithState:(VLCMediaPlayerState)state{
    
    if (state == VLCMediaPlayerStateError){
        
//        self.tipsLabel.text = NSLocalizedString(@"发生错误", nil);
        [APKAlertTool showAlertInViewController:self title:nil message:NSLocalizedString(@"发生错误", nil) confirmHandler:nil];
    }
    else if (state == VLCMediaPlayerStateStopped || state == VLCMediaPlayerStateEnded){
        
//        self.tipsLabel.text = self.isStopForLoadNewVideo ? nil : NSLocalizedString(@"播放结束", nil);
    }
    else{
        
//        self.tipsLabel.text = nil;
    }
}

- (void)updatePlayPauseButtonWithState:(VLCMediaPlayerState)state{
    
    switch (state) {
        case VLCMediaPlayerStateStopped:
        case VLCMediaPlayerStateEnded:
        case VLCMediaPlayerStateError:
        case VLCMediaPlayerStatePaused:
            self.playButton.hidden = NO;
            self.playButton.enabled = YES;
            self.pauseButton.hidden = YES;
            self.pauseButton.enabled = NO;
            break;
        case VLCMediaPlayerStatePlaying:
            self.playButton.hidden = YES;
            self.playButton.enabled = NO;
            self.pauseButton.hidden = NO;
            self.pauseButton.enabled = YES;
            break;
        default:
            break;
    }
}

- (void)updateSwitchVideoButtons{
    
    NSInteger numberOfVideos = self.URLs.count;
    if (numberOfVideos == 0) {
        
        self.previousButton.enabled = NO;
        self.nextButton.enabled = NO;
    }
    else{
        
        self.previousButton.enabled = self.currentIndex == 0 ? NO : YES;
        self.nextButton.enabled = self.currentIndex == (numberOfVideos - 1) ? NO : YES;
    }
}


- (IBAction)play:(UIButton *)sender {
    
    if (self.mediaPlayer.state == VLCMediaPlayerStatePaused) {
        
        int aInt = self.lastPLayTime;
        VLCTime *time = [VLCTime timeWithInt:aInt * 1000];
        [self.mediaPlayer setTime:time];
        [self.mediaPlayer play];
    }
    else{
        
        [self loadNewVideo];
    }
}

- (IBAction)pause:(UIButton *)sender {
    
    int currentSeconds = self.mediaPlayer.time.intValue / 1000;
    self.lastPLayTime = currentSeconds;
    [self.mediaPlayer pause];
}

- (IBAction)chengePlayItemWithSender:(UIButton *)sender {
    
    if (sender == self.previousButton) {
        
        self.currentIndex -= 1;
    }
    else if(sender == self.nextButton){
        
        self.currentIndex += 1;
    }
    [self updateSwitchVideoButtons];
    
//    NSURL *url = self.URLs[self.currentIndex];
//    self.titleLabel.text = [url.absoluteString lastPathComponent];
    [self getFileName];

    self.localFileURL = nil;
    [self loadNewVideo];
}

-(void)getFileName
{
    NSString *fileName = @"";
    
    if ([self.URLs.firstObject class] == [NSURL class]){
        NSURL *url = self.URLs[self.currentIndex];
        fileName = [url.absoluteString lastPathComponent];
    }else{
        APKLocalFile *file = self.localFileArr[self.currentIndex];
        fileName = file.info.name;
    }
    self.titleLabel.text = fileName;
}



- (IBAction)progressSliderValueChanged:(UISlider *)sender {
    
    [self updateProgress:sender.value];
}

- (IBAction)progressSliderTouchFinished:(UISlider *)sender {
    
    int aInt = sender.value;
     VLCTime *time = [VLCTime timeWithInt:aInt * 1000];
     [self.mediaPlayer setTime:time];
     [self.mediaPlayer play];
}




- (VLCMediaPlayer *)mediaPlayer{
    
    if (!_mediaPlayer) {
        
        //安卓的缓冲参数是600
        NSString *caching = [NSString stringWithFormat:@"--network-caching=%d",8000];
//        NSString *jitter = [NSString stringWithFormat:@"--clock-jitter=%d",8000];
        NSArray *options = @[caching,@"--cdda-caching=10000",@"--gain=0"];
        _mediaPlayer = [[VLCMediaPlayer alloc] initWithOptions:nil];
        _mediaPlayer.delegate = self;
        [_mediaPlayer addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    }
    return _mediaPlayer;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
