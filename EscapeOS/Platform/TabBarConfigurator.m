#import "TabBarConfigurator.h"

void EscapeOSConfigureTabBarController(UITabBarController *controller) {
    if (controller == nil) {
        return;
    }

    UITabBar *bar = controller.tabBar;

    // Never override with custom blur/material — let the system pick the modern style on iOS 26.
    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
    }

    // iOS 26 UITabBarController.tabBarMinimizeBehavior — invoked via runtime when linked against an older SDK.
    SEL minimizeSelector = NSSelectorFromString(@"setTabBarMinimizeBehavior:");
    if ([controller respondsToSelector:minimizeSelector]) {
        // UITabBarMinimizeBehaviorOnScrollDown == 1 in iOS 26 SDK headers.
        NSInteger onScrollDown = 1;
        NSMethodSignature *signature = [controller methodSignatureForSelector:minimizeSelector];
        if (signature != nil) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = controller;
            invocation.selector = minimizeSelector;
            [invocation setArgument:&onScrollDown atIndex:2];
            [invocation invoke];
        }
    }
}
