//
//  LGAudioEngine.m
//

#import "LGAudioEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

NSString *const LGAudioStateChangedNotification = @"LGAudioStateChangedNotification";

#pragma mark - LGSong

@implementation LGSong
+ (instancetype)fromDict:(NSDictionary *)d source:(NSString *)src {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    LGSong *s = [LGSong new];
    s.name     = [d[@"name"] isKindOfClass:[NSString class]] ? d[@"name"] : @"未知曲目";
    s.artist   = [d[@"artist"] isKindOfClass:[NSString class]] ? d[@"artist"] : @"未知歌手";
    s.urlString= [d[@"url"] isKindOfClass:[NSString class]] ? d[@"url"] : @"";
    s.picString= [d[@"pic"] isKindOfClass:[NSString class]] ? d[@"pic"] : @"";
    s.lrcString= [d[@"lrc"] isKindOfClass:[NSString class]] ? d[@"lrc"] : @"";
    id sid = d[@"id"] ?: d[@"songId"];
    s.songId   = [sid isKindOfClass:[NSString class]] ? sid : (sid ? [sid description] : @"");
    s.source   = src.length ? src : @"netease";
    return s;
}
@end

#pragma mark - 引擎

@interface LGAudioEngine () <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) UIWindow *bridgeWindow;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSTimer *ticker;
@property (nonatomic, strong) NSMutableDictionary<NSString *, void (^)(id, NSString *)> *pending;
@property (nonatomic, assign) NSInteger reqSeq;
@property (nonatomic, assign) BOOL tmProbed;
@property (nonatomic, assign) BOOL tmOK;
@property (nonatomic, strong) NSMutableArray<LGSong *> *songs;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) BOOL webReady;
@property (nonatomic, strong) NSMutableArray<void (^)(void)> *readyQueue;
@end

@implementation LGAudioEngine

+ (LGAudioEngine *)shared {
    static LGAudioEngine *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LGAudioEngine new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _pending = [NSMutableDictionary dictionary];
        _songs   = [NSMutableArray array];
        _readyQueue = [NSMutableArray array];
        _index = -1;
    }
    return self;
}

#pragma mark - 启动

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.webView) return;
        [self setupAudioSession];
        [self setupBridge];
        [self setupPlayer];
    });
}

- (void)setupAudioSession {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [s setCategory:AVAudioSessionCategoryPlayback error:&err];
    [s setActive:YES error:&err];
}

- (void)setupBridge {
    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    WKUserContentController *ucc = [WKUserContentController new];
    [ucc addScriptMessageHandler:self name:@"lg"];
    cfg.userContentController = ucc;
    cfg.allowsInlineMediaPlayback = YES;

    NSString *html = @"<!doctype html><meta charset=utf-8><script>\
function post(t,p){try{window.webkit.messageHandlers.lg.postMessage({type:t,payload:p});}catch(e){}}\
window.__lgCall=function(rid,method,argsJson){\
  try{\
    if(typeof TM==='undefined'){post('cb',{rid:rid,err:'TM_NOT_FOUND'});return;}\
    if(typeof TM[method]!=='function'){post('cb',{rid:rid,err:'TM_NO_METHOD:'+method});return;}\
    var args=JSON.parse(argsJson||'[]');\
    var r=TM[method].apply(TM,args);\
    if(r&&typeof r.then==='function'){r.then(function(v){post('cb',{rid:rid,data:v});}).catch(function(e){post('cb',{rid:rid,err:String(e)});});}\
    else{post('cb',{rid:rid,data:r});}\
  }catch(e){post('cb',{rid:rid,err:String(e)});}\
};\
post('ready',{});\
</script>";

    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)
                                       configuration:cfg];
    wv.navigationDelegate = self;
    wv.hidden = YES;
    wv.opaque = NO;
    wv.backgroundColor = [UIColor clearColor];
    self.webView = wv;

    // 需要一个宿主 window，否则部分系统版本不执行 JS
    UIWindow *win = [[UIWindow alloc] initWithFrame:CGRectMake(-10, -10, 1, 1)];
    win.windowLevel = UIWindowLevelNormal - 2;
    win.hidden = NO;
    win.rootViewController = [UIViewController new];
    [win.rootViewController.view addSubview:wv];
    self.bridgeWindow = win;

    [wv loadHTMLString:html baseURL:[NSURL URLWithString:@"https://music.163.com"]];
}

- (void)setupPlayer {
    self.player = [AVPlayer new];
    __weak typeof(self) ws = self;
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        [ws tick];
    }];
}

- (void)tick {
    if (!self.player.currentItem) return;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:LGAudioStateChangedNotification object:nil];
}

#pragma mark - JS 桥

- (void)userContentController:(WKUserContentController *)ucc
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"lg"]) return;
    NSDictionary *body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) return;

    NSString *type = body[@"type"];
    NSDictionary *payload = body[@"payload"];
    if (![payload isKindOfClass:[NSDictionary class]]) payload = @{};

    if ([type isEqualToString:@"ready"]) {
        self.webReady = YES;
        [self probeTM];
        NSArray *q = [self.readyQueue copy];
        [self.readyQueue removeAllObjects];
        for (void (^b)(void) in q) { if (b) b(); }
        return;
    }

    if ([type isEqualToString:@"cb"]) {
        NSString *rid = payload[@"rid"];
        if (!rid) return;
        void (^cb)(id, NSString *) = self.pending[rid];
        [self.pending removeObjectForKey:rid];
        if (!cb) return;
        id data = payload[@"data"];
        NSString *err = payload[@"err"];
        cb(data, err);
    }
}

- (void)probeTM {
    if (self.tmProbed) return;
    self.tmProbed = YES;
    __weak typeof(self) ws = self;
    [self.webView evaluateJavaScript:@"typeof TM !== 'undefined'"
                   completionHandler:^(id v, NSError *e) {
        ws.tmOK = [v boolValue];
    }];
}

- (void)whenBridgeReady:(void (^)(void))block {
    if (self.webReady) { block(); return; }
    if (block) [self.readyQueue addObject:[block copy]];
    if (!self.webView) [self start];
}

/// 调用 TM API
- (void)callTM:(NSString *)method
          args:(NSArray *)args
    completion:(void (^)(id data, NSString *err))completion
{
    [self whenBridgeReady:^{
        NSUInteger rid = (NSUInteger)(++self.reqSeq);
        NSString *ridStr = [NSString stringWithFormat:@"r%lu", (unsigned long)rid];

        NSError *jerr = nil;
        NSData *jd = [NSJSONSerialization dataWithJSONObject:args options:0 error:&jerr];
        NSString *argsJson = @"[]";
        if (jd) argsJson = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];

        NSString *js = [NSString stringWithFormat:@"window.__lgCall('%@','%@',%@)",
                        ridStr, method, argsJson];

        if (completion) self.pending[ridStr] = [completion copy];
        [self.webView evaluateJavaScript:js completionHandler:^(id v, NSError *e) {
            if (e && completion) {
                void (^cb)(id, NSString *) = self.pending[ridStr];
                [self.pending removeObjectForKey:ridStr];
                if (cb) cb(nil, e.localizedDescription ?: @"JS_ERROR");
            }
        }];
    }];
}

#pragma mark - 歌单 / 搜索

- (void)loadPlaylist:(NSString *)playlistId
              source:(NSString *)source
          completion:(void (^)(NSArray<LGSong *> *, NSError *))completion
{
    if (!playlistId.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"LG" code:1
                                                        userInfo:@{NSLocalizedDescriptionKey:@"歌单 ID 为空"}]);
        return;
    }
    NSString *src = source.length ? source : @"netease";
    __weak typeof(self) ws = self;
    [self callTM:@"loadPlaylist" args:@[playlistId, src] completion:^(id data, NSString *err) {
        if (err || ![data isKindOfClass:[NSArray class]]) {
            // TM 不可用 → 兜底：把歌单 ID 当作可直接播放的曲目源提示
            if (completion) completion(nil, [NSError errorWithDomain:@"LG" code:2
                userInfo:@{NSLocalizedDescriptionKey: err ?: @"TM 不可用"}]);
            return;
        }
        NSMutableArray<LGSong *> *list = [NSMutableArray array];
        for (NSDictionary *d in (NSArray *)data) {
            LGSong *s = [LGSong fromDict:d source:src];
            if (s) [list addObject:s];
        }
        [ws.songs setArray:list];
        ws.index = list.count ? 0 : -1;
        if (completion) completion(list, nil);
    }];
}

- (void)searchKeyword:(NSString *)keyword
               source:(NSString *)source
           completion:(void (^)(NSArray<LGSong *> *, NSError *))completion
{
    if (!keyword.length) {
        if (completion) completion(@[], nil);
        return;
    }
    NSString *src = source.length ? source : @"netease";

    // 优先 TM（若桥提供了 search），否则走网易云公开搜索
    __weak typeof(self) ws = self;
    [self callTM:@"search" args:@[keyword, src] completion:^(id data, NSString *err) {
        if (!err && [data isKindOfClass:[NSArray class]] && [(NSArray *)data count] > 0) {
            NSMutableArray<LGSong *> *list = [NSMutableArray array];
            for (NSDictionary *d in (NSArray *)data) {
                LGSong *s = [LGSong fromDict:d source:src];
                if (s) [list addObject:s];
            }
            if (completion) completion(list, nil);
            return;
        }
        [ws fallbackSearch:keyword source:src completion:completion];
    }];
}

- (void)fallbackSearch:(NSString *)kw
                source:(NSString *)src
            completion:(void (^)(NSArray<LGSong *> *, NSError *))completion
{
    NSString *q = [kw stringByAddingPercentEncodingWithAllowedCharacters:
                   [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:
        @"https://music.163.com/api/search/get/web?s=%@&type=1&limit=20", q];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) { if (completion) completion(@[], nil); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"https://music.163.com/" forHTTPHeaderField:@"Referer"];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) { if (completion) completion(@[], e); return; }
        NSError *jerr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:&jerr];
        NSMutableArray<LGSong *> *out = [NSMutableArray array];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *result = obj[@"result"];
            NSArray *songs = result[@"songs"];
            if ([songs isKindOfClass:[NSArray class]]) {
                for (NSDictionary *sd in songs) {
                    LGSong *s = [LGSong new];
                    s.songId = [NSString stringWithFormat:@"%@", sd[@"id"]];
                    s.name   = sd[@"name"] ?: @"未知曲目";
                    NSArray *ar = sd[@"artists"];
                    if ([ar isKindOfClass:[NSArray class]] && ar.count) {
                        NSMutableArray *nm = [NSMutableArray array];
                        for (NSDictionary *a in ar) {
                            if (a[@"name"]) [nm addObject:a[@"name"]];
                        }
                        s.artist = [nm componentsJoinedByString:@"/"];
                    } else {
                        s.artist = @"未知歌手";
                    }
                    s.source = @"netease";
                    s.urlString = [NSString stringWithFormat:
                        @"https://music.163.com/song/media/outer/url?id=%@.mp3", s.songId];
                    [out addObject:s];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(out, nil);
        });
    }];
    [t resume];
}

#pragma mark - 播放

- (void)playSong:(LGSong *)song {
    if (!song) return;
    if (![self.songs containsObject:song]) [self.songs addObject:song];
    self.index = [self.songs indexOfObject:song];

    NSString *u = song.urlString;
    if (!u.length && song.songId.length) {
        u = [NSString stringWithFormat:@"https://music.163.com/song/media/outer/url?id=%@.mp3", song.songId];
    }
    if (!u.length) return;

    NSURL *url = [NSURL URLWithString:u];
    if (!url) return;

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    [self.player replaceCurrentItemWithPlayerItem:item];
    [self.player play];

    [[NSNotificationCenter defaultCenter] postNotificationName:LGAudioStateChangedNotification object:nil];

    // 播完自动下一首
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onItemEnd)
        name:AVPlayerItemDidPlayToEndTimeNotification object:item];
}

- (void)onItemEnd { [self next]; }

- (void)togglePlayPause {
    if (self.player.rate > 0.0) [self.player pause];
    else [self.player play];
    [[NSNotificationCenter defaultCenter] postNotificationName:LGAudioStateChangedNotification object:nil];
}

- (void)next {
    if (!self.songs.count) return;
    self.index = (self.index + 1) % (NSInteger)self.songs.count;
    [self playSong:self.songs[self.index]];
}

- (void)previous {
    if (!self.songs.count) return;
    self.index = (self.index - 1 + (NSInteger)self.songs.count) % (NSInteger)self.songs.count;
    [self playSong:self.songs[self.index]];
}

- (void)seekTo:(NSTimeInterval)time {
    CMTime t = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    [self.player seekToTime:t];
}

- (void)stop {
    [self.player pause];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:LGAudioStateChangedNotification object:nil];
}

#pragma mark - 只读属性

- (LGSong *)currentSong {
    if (self.index >= 0 && self.index < (NSInteger)self.songs.count) return self.songs[self.index];
    return nil;
}
- (BOOL)isPlaying { return self.player.rate > 0.0; }
- (NSArray<LGSong *> *)playlist { return [self.songs copy]; }
- (BOOL)tmAvailable { return self.tmOK; }

- (NSTimeInterval)currentTime {
    CMTime t = self.player.currentTime;
    if (CMTIME_IS_INVALID(t)) return 0;
    return CMTimeGetSeconds(t);
}
- (NSTimeInterval)duration {
    AVPlayerItem *it = self.player.currentItem;
    if (!it) return 0;
    CMTime d = it.duration;
    if (CMTIME_IS_INVALID(d)) return 0;
    return CMTimeGetSeconds(d);
}
- (CGFloat)progress {
    NSTimeInterval d = self.duration;
    if (d <= 0) return 0;
    return (CGFloat)(self.currentTime / d);
}

@end
