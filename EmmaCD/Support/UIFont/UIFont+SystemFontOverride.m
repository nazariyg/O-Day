#import "UIFont+SystemFontOverride.h"
#import <objc/runtime.h>


NSString *const FORegularFontName = @"AppleSDGothicNeo-Regular";
NSString *const FOBoldFontName = @"AppleSDGothicNeo-Bold";
NSString *const FOItalicFontName = @"AppleSDGothicNeo-Regular";
NSString *const FOLightFontName = @"AppleSDGothicNeo-Light";
NSString *const FOMediumFontName = @"AppleSDGothicNeo-Medium";
NSString *const FODemiFontName = @"AppleSDGothicNeo-SemiBold";


@implementation UIFont (SystemFontOverride)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

+ (void)replaceClassSelector:(SEL)originalSelector withSelector:(SEL)modifiedSelector {
    Method originalMethod = class_getClassMethod(self, originalSelector);
    Method modifiedMethod = class_getClassMethod(self, modifiedSelector);
    method_exchangeImplementations(originalMethod, modifiedMethod);
}

+ (void)replaceInstanceSelector:(SEL)originalSelector withSelector:(SEL)modifiedSelector {
    Method originalDecoderMethod = class_getInstanceMethod(self, originalSelector);
    Method modifiedDecoderMethod = class_getInstanceMethod(self, modifiedSelector);
    method_exchangeImplementations(originalDecoderMethod, modifiedDecoderMethod);
}

+ (UIFont *)regularFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:FORegularFontName size:size];
}

+ (UIFont *)boldFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:FOBoldFontName size:size];
}

+ (UIFont *)italicFontOfSize:(CGFloat)fontSize
{
    return [UIFont fontWithName:FOItalicFontName size:fontSize];
}

+ (UIFont *)lightFontOfSize:(CGFloat)fontSize
{
    return [UIFont fontWithName:FOLightFontName size:fontSize];
}

+ (UIFont *)demiFontOfSize:(CGFloat)fontSize
{
    return [UIFont fontWithName:FODemiFontName size:fontSize];
}

- (id)initCustomWithCoder:(NSCoder *)aDecoder {
    BOOL result = [aDecoder containsValueForKey:@"UIFontDescriptor"];

    if (result) {
        UIFontDescriptor *descriptor = [aDecoder decodeObjectForKey:@"UIFontDescriptor"];

        NSString *fontName;
        if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontRegularUsage"]) {
            fontName = FORegularFontName;
        }
        else if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontEmphasizedUsage"]) {
            fontName = FOBoldFontName;
        }
        else if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontObliqueUsage"]) {
            fontName = FOItalicFontName;
        }
        else if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontLightUsage"]) {
            fontName = FOLightFontName;
        }
        else if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontMediumUsage"]) {
            fontName = FOMediumFontName;
        }
        else if ([descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"] isEqualToString:@"CTFontDemiUsage"]) {
            fontName = FODemiFontName;
        }
        else {
            NSLog(@"%@", descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"]);
            fontName = descriptor.fontAttributes[@"NSFontNameAttribute"];
        }

        return [UIFont fontWithName:fontName size:descriptor.pointSize];
    }

    self = [self initCustomWithCoder:aDecoder];

    return self;
}

+ (void)load
{
    [self replaceClassSelector:@selector(systemFontOfSize:) withSelector:@selector(regularFontWithSize:)];
    [self replaceClassSelector:@selector(boldSystemFontOfSize:) withSelector:@selector(boldFontWithSize:)];
    [self replaceClassSelector:@selector(italicSystemFontOfSize:) withSelector:@selector(italicFontOfSize:)];

    [self replaceInstanceSelector:@selector(initWithCoder:) withSelector:@selector(initCustomWithCoder:)];
}

#pragma clang diagnostic pop

@end



