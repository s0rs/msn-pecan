/*
 * Principal class of the Adium plugin bundle.
 *
 * Conforms to AILibpurplePlugin so Adium will:
 *   - call installPlugin (register the WLM/Escargot service), and
 *   - call loadLibpurplePlugin once libpurple is ready (register the prpl).
 */

#import <Cocoa/Cocoa.h>
#import <Adium/AIPlugin.h>
#import <AdiumLibpurple/AILibpurplePlugin.h>

@interface PecanPlugin : AIPlugin <AILibpurplePlugin> {
}
@end
