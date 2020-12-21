//
//  APKDVRFileCell.m
//  微米
//
//  Created by Mac on 17/4/21.
//  Copyright © 2017年 APK. All rights reserved.
//

#import "APKDVRFileCell.h"

@implementation APKDVRFileCell

- (void)configureCell:(APKDVRFile *)file{
    
    self.label.text = file.name;
    self.subLabel.text = file.size;
    
    if (file.thumbnailPath) {
        UIImage *image = [UIImage imageWithContentsOfFile:file.thumbnailPath];
        self.imagev.image = image;
    }

}

@end
