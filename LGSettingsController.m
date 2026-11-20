//
//  LGSettingsController.m
//

#import "LGSettingsController.h"
#import "LGCore.h"
#import "LGAudioEngine.h"

typedef NS_ENUM(NSInteger, LGSection) {
    LGSectionMaster = 0,
    LGSectionMusic,
    LGSectionBar,
    LGSectionArc,
    LGSectionQuick,
    LGSectionAbout,
    LGSectionCount
};

static NSString *const kSymbolChoices[] = {
    @"gearshape.fill", @"folder.fill", @"magnifyingglass", @"envelope.fill",
    @"person.2.fill", @"person.crop.circle", @"location.north.circle.fill",
    @"qrcode.viewfinder", @"creditcard.fill", @"photo.on.rectangle",
    @"bookmark.fill", @"music.note", @"circle.grid.2x2.fill", @""
};
static const NSInteger kSymbolCount = sizeof(kSymbolChoices) / sizeof(kSymbolChoices[0]);

@implementation LGSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"液态底栏";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self action:@selector(onDone)];
}

- (void)onDone {
    [[LGConfig shared] save];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return LGSectionCount; }

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case LGSectionMaster: return @"总开关";
        case LGSectionMusic:  return @"音乐";
        case LGSectionBar:    return @"底栏外观";
        case LGSectionArc:    return @"弧带按钮";
        case LGSectionQuick:  return @"快捷面板";
        case LGSectionAbout:  return @"关于";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case LGSectionMaster: return 2;
        case LGSectionMusic:  return 5;
        case LGSectionBar:    return 6;
        case LGSectionArc:    return 5;
        case LGSectionQuick:  return 3;
        case LGSectionAbout:  return 2;
        default: return 0;
    }
}

- (UITableViewCell *)cellWithStyle:(UITableViewCellStyle)style {
    NSString *rid = [NSString stringWithFormat:@"c%ld", (long)style];
    UITableViewCell *c = [self.tableView dequeueReusableCellWithIdentifier:rid];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:rid];
    return c;
}

- (UISwitch *)switchWithOn:(BOOL)on action:(SEL)action {
    UISwitch *sw = [UISwitch new];
    sw.on = on;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return sw;
}

- (UISlider *)sliderWith:(CGFloat)v min:(CGFloat)mn max:(CGFloat)mx tag:(NSInteger)tag {
    UISlider *sl = [UISlider new];
    sl.minimumValue = mn; sl.maximumValue = mx; sl.value = v;
    sl.tag = tag;
    [sl addTarget:self action:@selector(onSlider:) forControlEvents:UIControlEventValueChanged];
    return sl;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    LGConfig *cfg = [LGConfig shared];
    UITableViewCell *c = [self cellWithStyle:UITableViewCellStyleValue1];

    if (ip.section == LGSectionMaster) {
        if (ip.row == 0) {
            c.textLabel.text = @"启用液态底栏";
            c.accessoryView = [self switchWithOn:cfg.enabled action:@selector(onToggleEnabled:)];
        } else {
            c.textLabel.text = @"点击震动反馈";
            c.accessoryView = [self switchWithOn:cfg.hapticOnTap action:@selector(onToggleHaptic:)];
        }
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        return c;
    }

    if (ip.section == LGSectionMusic) {
        LGAudioEngine *e = [LGAudioEngine shared];
        if (ip.row == 0) {
            c.textLabel.text = @"当前曲目";
            LGSong *s = e.currentSong;
            c.detailTextLabel.text = s ? [NSString stringWithFormat:@"%@ - %@", s.name, s.artist] : @"未播放";
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        if (ip.row == 1) {
            c.textLabel.text = @"歌单 ID";
            c.detailTextLabel.text = cfg.playlistId.length ? cfg.playlistId : @"点击设置";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (ip.row == 2) {
            c.textLabel.text = @"音源";
            c.detailTextLabel.text = [cfg.musicSource isEqualToString:@"qq"] ? @"QQ 音乐" : @"网易云";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        if (ip.row == 3) {
            c.textLabel.text = @"搜索并播放";
            c.detailTextLabel.text = e.tmAvailable ? @"TM 已连接" : @"使用公开接口";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        c.textLabel.text = @"启动时自动播放";
        c.accessoryView = [self switchWithOn:cfg.autoPlayOnLaunch action:@selector(onToggleAutoPlay:)];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        return c;
    }

    if (ip.section == LGSectionBar) {
        if (ip.row == 0 || ip.row == 1) {
            BOOL top = (ip.row == 0);
            c.textLabel.text = top ? @"上边缘弧度" : @"下边缘弧度";
            c.detailTextLabel.text = [NSString stringWithFormat:@"%.0f", top ? cfg.topSag : cfg.bottomSag];
            UISlider *sl = [self sliderWith:(top ? cfg.topSag : cfg.bottomSag)
                                        min:0 max:40 tag:(top ? 100 : 101)];
            c.accessoryView = sl;
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        if (ip.row == 2) {
            c.textLabel.text = @"弧带厚度";
            c.detailTextLabel.text = [NSString stringWithFormat:@"%.0f", cfg.thickness];
            c.accessoryView = [self sliderWith:cfg.thickness min:40 max:92 tag:102];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        if (ip.row == 3) {
            c.textLabel.text = @"距底部";
            c.detailTextLabel.text = [NSString stringWithFormat:@"%.0f", cfg.bottomOffset];
            c.accessoryView = [self sliderWith:cfg.bottomOffset min:-40 max:60 tag:103];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        if (ip.row == 4) {
            c.textLabel.text = @"左侧圆钮";
            NSString *s = cfg.orbIcons.count > 0 ? cfg.orbIcons[0] : @"";
            c.detailTextLabel.text = s.length ? s : @"隐藏";
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        c.textLabel.text = @"右侧圆钮";
        {
            NSString *s = cfg.orbIcons.count > 1 ? cfg.orbIcons[1] : @"";
            c.detailTextLabel.text = s.length ? s : @"隐藏";
        }
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    if (ip.section == LGSectionArc) {
        static NSString *const names[] = {@"第 1 项（信封/未读）", @"第 2 项", @"中间头像", @"第 4 项", @"第 5 项"};
        c.textLabel.text = names[ip.row];
        if (ip.row == 2) {
            c.detailTextLabel.text = @"跟随当前曲目";
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            c.accessoryType = UITableViewCellAccessoryNone;
            return c;
        }
        NSString *s = (ip.row < (NSInteger)cfg.arcIcons.count) ? cfg.arcIcons[ip.row] : @"";
        c.detailTextLabel.text = s.length ? s : @"隐藏";
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }

    if (ip.section == LGSectionQuick) {
        if (ip.row == 0) {
            c.textLabel.text = @"启用快捷面板";
            c.accessoryView = [self switchWithOn:cfg.quickPanelEnabled action:@selector(onToggleQuick:)];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        if (ip.row == 1) {
            static NSString *const edges[] = {@"左侧门轴", @"右侧门轴", @"底部门轴"};
            c.textLabel.text = @"展开方式";
            c.detailTextLabel.text = edges[MAX(0, MIN(2, cfg.hingeEdge))];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return c;
        }
        c.textLabel.text = @"显示内容";
        c.detailTextLabel.text = @"微信内置入口";
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        return c;
    }

    // About
    if (ip.row == 0) {
        c.textLabel.text = @"版本";
        c.detailTextLabel.text = @"1.0.0";
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        c.textLabel.text = @"重置全部设置";
        c.textLabel.textColor = [UIColor systemRedColor];
        c.detailTextLabel.text = @"";
    }
    return c;
}

#pragma mark - 交互

- (void)onToggleEnabled:(UISwitch *)sw {
    [LGConfig shared].enabled = sw.on;
    [[LGConfig shared] save];
    if (sw.on) [[LGCore shared] start]; else [[LGCore shared] stop];
}
- (void)onToggleHaptic:(UISwitch *)sw {
    [LGConfig shared].hapticOnTap = sw.on;
    [[LGConfig shared] save];
}
- (void)onToggleAutoPlay:(UISwitch *)sw {
    [LGConfig shared].autoPlayOnLaunch = sw.on;
    [[LGConfig shared] save];
}
- (void)onToggleQuick:(UISwitch *)sw {
    [LGConfig shared].quickPanelEnabled = sw.on;
    [[LGConfig shared] save];
}

- (void)onSlider:(UISlider *)sl {
    LGConfig *cfg = [LGConfig shared];
    switch (sl.tag) {
        case 100: cfg.topSag = sl.value; break;
        case 101: cfg.bottomSag = sl.value; break;
        case 102: cfg.thickness = sl.value; break;
        case 103: cfg.bottomOffset = sl.value; break;
        default: break;
    }
    [cfg save];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    LGConfig *cfg = [LGConfig shared];

    if (ip.section == LGSectionMusic) {
        if (ip.row == 1) { [self promptPlaylistId]; return; }
        if (ip.row == 2) { [self chooseSource]; return; }
        if (ip.row == 3) { [self promptSearch]; return; }
    }

    if (ip.section == LGSectionBar && (ip.row == 4 || ip.row == 5)) {
        [self chooseSymbolForOrb:(ip.row == 4 ? 0 : 1)];
        return;
    }

    if (ip.section == LGSectionArc && ip.row != 2) {
        [self chooseSymbolForArc:ip.row];
        return;
    }

    if (ip.section == LGSectionQuick && ip.row == 1) {
        [self chooseHinge];
        return;
    }

    if (ip.section == LGSectionAbout && ip.row == 1) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"重置设置"
            message:@"将恢复全部默认值" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
            NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.wclg.liquidarc"];
            [d removePersistentDomainForName:@"com.wclg.liquidarc"];
            [d synchronize];
            [self.tableView reloadData];
            [[LGCore shared] reloadUI];
        }]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

#pragma mark - 子面板

- (void)promptPlaylistId {
    LGConfig *cfg = [LGConfig shared];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"歌单 ID"
        message:@"网易云：playlist?id= 后面的数字\nQQ 音乐：playlist/ 后面的数字"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"例如 2619366284";
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.text = cfg.playlistId;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) ws = self;
    [a addAction:[UIAlertAction actionWithTitle:@"载入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *t = a.textFields.firstObject.text ?: @"";
        cfg.playlistId = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [cfg save];
        [[LGAudioEngine shared] start];
        [[LGAudioEngine shared] loadPlaylist:cfg.playlistId source:cfg.musicSource
                                  completion:^(NSArray<LGSong *> *songs, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *msg = songs.count
                    ? [NSString stringWithFormat:@"已载入 %lu 首", (unsigned long)songs.count]
                    : [NSString stringWithFormat:@"载入失败：%@", err.localizedDescription ?: @"未知"];
                UIAlertController *r = [UIAlertController alertControllerWithTitle:@"歌单"
                    message:msg preferredStyle:UIAlertControllerStyleAlert];
                [r addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                [ws presentViewController:r animated:YES completion:nil];
                [ws.tableView reloadData];
                if (songs.count) [[LGAudioEngine shared] playSong:songs.firstObject];
            });
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)chooseSource {
    LGConfig *cfg = [LGConfig shared];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"音源"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *s in @[@"netease", @"qq"]) {
        NSString *t = [s isEqualToString:@"qq"] ? @"QQ 音乐" : @"网易云";
        [a addAction:[UIAlertAction actionWithTitle:t style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            cfg.musicSource = s;
            [cfg save];
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                            CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)promptSearch {
    LGConfig *cfg = [LGConfig shared];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"搜索音乐"
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"歌名 / 歌手";
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) ws = self;
    [a addAction:[UIAlertAction actionWithTitle:@"搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        NSString *kw = a.textFields.firstObject.text ?: @"";
        if (!kw.length) return;
        [[LGAudioEngine shared] start];
        [[LGAudioEngine shared] searchKeyword:kw source:cfg.musicSource
                                  completion:^(NSArray<LGSong *> *songs, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!songs.count) {
                    UIAlertController *r = [UIAlertController alertControllerWithTitle:@"搜索"
                        message:@"没有结果" preferredStyle:UIAlertControllerStyleAlert];
                    [r addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
                    [ws presentViewController:r animated:YES completion:nil];
                    return;
                }
                UIAlertController *list = [UIAlertController alertControllerWithTitle:@"选择播放"
                    message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                NSInteger n = MIN((NSInteger)songs.count, 12);
                for (NSInteger i = 0; i < n; i++) {
                    LGSong *s = songs[i];
                    NSString *t = [NSString stringWithFormat:@"%@ - %@", s.name, s.artist];
                    [list addAction:[UIAlertAction actionWithTitle:t style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
                        [[LGAudioEngine shared] playSong:s];
                    }]];
                }
                [list addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                list.popoverPresentationController.sourceView = ws.view;
                list.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(ws.view.bounds),
                                                                           CGRectGetMidY(ws.view.bounds), 1, 1);
                [ws presentViewController:list animated:YES completion:nil];
            });
        }];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)chooseSymbolForOrb:(NSInteger)idx {
    [self pickSymbolWithTitle:[NSString stringWithFormat:@"%@圆钮", idx == 0 ? @"左侧" : @"右侧"]
                     callback:^(NSString *sym) {
        LGConfig *cfg = [LGConfig shared];
        NSMutableArray *arr = [cfg.orbIcons mutableCopy] ?: [@[@"", @""] mutableCopy];
        while (arr.count < 2) [arr addObject:@""];
        arr[idx] = sym;
        cfg.orbIcons = arr;
        [cfg save];
        [self.tableView reloadData];
        [[LGCore shared] reloadUI];
    }];
}

- (void)chooseSymbolForArc:(NSInteger)idx {
    static NSString *const names[] = {@"第 1 项", @"第 2 项", @"", @"第 4 项", @"第 5 项"};
    [self pickSymbolWithTitle:names[idx] callback:^(NSString *sym) {
        LGConfig *cfg = [LGConfig shared];
        NSMutableArray *arr = [cfg.arcIcons mutableCopy] ?: [@[@"", @"", @"", @"", @""] mutableCopy];
        while (arr.count < 5) [arr addObject:@""];
        arr[idx] = sym;
        cfg.arcIcons = arr;
        [cfg save];
        [self.tableView reloadData];
        [[LGCore shared] reloadUI];
    }];
}

- (void)pickSymbolWithTitle:(NSString *)title callback:(void (^)(NSString *))cb {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
        message:@"选择 SF Symbol（最后一项为隐藏）" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger i = 0; i < kSymbolCount; i++) {
        NSString *sym = kSymbolChoices[i];
        NSString *t = sym.length ? sym : @"隐藏";
        [a addAction:[UIAlertAction actionWithTitle:t style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            if (cb) cb(sym);
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                            CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

- (void)chooseHinge {
    LGConfig *cfg = [LGConfig shared];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"门轴方向"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"左侧门轴（向右展开）", @"右侧门轴（向左展开）", @"底部门轴（向上翻开）"];
    for (NSInteger i = 0; i < 3; i++) {
        [a addAction:[UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            cfg.hingeEdge = i;
            [cfg save];
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                            CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

@end
