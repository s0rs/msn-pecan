#import "PecanService.h"
#import "PecanAccount.h"
#import <Adium/AIAccountViewController.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AISharedAdium.h>
#import <Adium/AIServiceIcons.h>
#import <AIUtilities/AIStringUtilities.h>

@implementation PecanService

//Account Creation -----------------------------------------------------------
- (Class)accountClass
{
	return [PecanAccount class];
}

/*
 * Use the stock Adium account view controller. Its default nibs (loaded from
 * the Adium framework) provide the username/password fields plus the login
 * server/port options, which is all msn-pecan needs — the prpl already
 * defaults the server to msnmsgr.escargot.chat.
 */
- (AIAccountViewController *)accountViewController
{
	return [AIAccountViewController accountViewController];
}

- (DCJoinChatViewController *)joinChatView
{
	return nil;
}

//Service Description --------------------------------------------------------
- (NSString *)serviceCodeUniqueID
{
	return @"libpurple-msn-pecan";
}

- (NSString *)serviceID
{
	return @"WLM";
}

- (NSString *)serviceClass
{
	return @"WLM";
}

- (NSString *)shortDescription
{
	return @"WLM";
}

- (NSString *)longDescription
{
	return @"WLM (Escargot)";
}

- (NSCharacterSet *)allowedCharacters
{
	return [NSCharacterSet characterSetWithCharactersInString:
		@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-@"];
}

- (NSUInteger)allowedLength
{
	return 255;
}

- (BOOL)caseSensitive
{
	return NO;
}

- (AIServiceImportance)serviceImportance
{
	return AIServiceSecondary;
}

/*
 * Provide a service icon. Adium's icon packs have no "WLM" entry, so
 * AIServiceIcons falls back to calling this. If we return nil, the contact-list
 * cell's user-icon draw (drawUserIconInRect) gets a nil image, [nil
 * drawRoundedInRect:...] returns NSZeroRect, and the display name is then drawn
 * into a zero-size rect — every contact row renders BLANK. Borrow the legacy
 * MSN icon (WLM == Windows Live Messenger), which the default packs do ship.
 */
- (NSImage *)defaultServiceIconOfType:(AIServiceIconType)iconType
{
	/*
	 * Return a COPY, not the shared cached MSN image. AIServiceIcons caches the
	 * icon we return under our own serviceID and calls -setFlipped: on it for the
	 * contact list's flipped coordinate space. If we handed back the shared MSN
	 * instance, that flip would mutate the one image used everywhere — leaving the
	 * icon upside-down in the accounts list while correct in the contact list. A
	 * private copy keeps each list's flip state independent.
	 */
	NSImage *msn = [AIServiceIcons serviceIconForServiceID:@"MSN"
													  type:iconType
												 direction:AIIconNormal];
	return [[msn copy] autorelease];
}

- (BOOL)canCreateGroupChats
{
	return NO;
}

- (NSString *)userNameLabel
{
	return AILocalizedString(@"E-mail Address", nil);
}

//Statuses -------------------------------------------------------------------
- (void)registerStatuses
{
	[adium.statusController registerStatus:STATUS_NAME_AVAILABLE
						   withDescription:[adium.statusController localizedDescriptionForCoreStatusName:STATUS_NAME_AVAILABLE]
									ofType:AIAvailableStatusType
								forService:self];

	[adium.statusController registerStatus:STATUS_NAME_AWAY
						   withDescription:[adium.statusController localizedDescriptionForCoreStatusName:STATUS_NAME_AWAY]
									ofType:AIAwayStatusType
								forService:self];

	[adium.statusController registerStatus:STATUS_NAME_BUSY
						   withDescription:[adium.statusController localizedDescriptionForCoreStatusName:STATUS_NAME_BUSY]
									ofType:AIAwayStatusType
								forService:self];

	[adium.statusController registerStatus:STATUS_NAME_INVISIBLE
						   withDescription:[adium.statusController localizedDescriptionForCoreStatusName:STATUS_NAME_INVISIBLE]
									ofType:AIInvisibleStatusType
								forService:self];
}

@end
