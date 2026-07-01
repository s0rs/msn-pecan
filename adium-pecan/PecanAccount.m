#import "PecanAccount.h"
#import <Adium/AIAccount.h>
#import <prpl.h>
#import <account.h>
#import <status.h>
#import <blist.h>

@implementation PecanAccount

/* Bind this Adium account to the msn-pecan prpl. */
- (const char *)protocolPlugin
{
	return "prpl-msn-pecan";
}

/*
 * Escargot/WLM accounts are e-mail addresses; the UID is already the full
 * account name, so the default CBPurpleAccount behaviour (return the UID)
 * is what we want. Provided explicitly for clarity.
 */
- (const char *)purpleAccountName
{
	return [self.UID UTF8String];
}

/*
 * Escargot/WLM always connects to a fixed server (the prpl's own "server"
 * option, default msnmsgr.escargot.chat). Returning NO stops CBPurpleAccount
 * from demanding an Adium-level connect host before connecting — without this,
 * an account with no host set flaps connect/disconnect instead of signing in.
 */
- (BOOL)connectivityBasedOnNetworkReachability
{
	return NO;
}

/*
 * Pre-fill the login server / port for a new account.
 *
 * Adium's account-setup UI shows a Connect Host / Port field (stored under
 * GROUP_ACCOUNT_STATUS), but leaves it blank by default — confusing, since WLM
 * always uses Escargot's server. CBPurpleAccount maps that host/port to the
 * prpl's "server"/"port" options via -hostForPurple, so seeding the Adium prefs
 * both pre-populates the visible fields and drives the connection. Only set them
 * when unset, so a user's own edits stick.
 */
- (void)initAccount
{
	[super initAccount];

	if (![self preferenceForKey:KEY_CONNECT_HOST group:GROUP_ACCOUNT_STATUS])
		[self setPreference:@"msnmsgr.escargot.chat"
		             forKey:KEY_CONNECT_HOST
		              group:GROUP_ACCOUNT_STATUS];

	if (![self preferenceForKey:KEY_CONNECT_PORT group:GROUP_ACCOUNT_STATUS])
		[self setPreference:[NSNumber numberWithInt:1863]
		             forKey:KEY_CONNECT_PORT
		              group:GROUP_ACCOUNT_STATUS];
}

- (void)configurePurpleAccount
{
	/*
	 * Build the account's (and its buddies') libpurple presence in place.
	 *
	 * Our prpl lives in an Adium plugin bundle registered during purple's ui_init
	 * (init_all_plugins). libpurple loaded this account and its buddies BEFORE the
	 * prpl was registered, so their presences were built via purple_prpl_get_statuses()
	 * with no prpl — i.e. with ZERO status objects. Consequences:
	 *   - Account: get_active_status()==NULL → SLPurpleCocoaAdapter's setStatusID
	 *     never calls purple_account_connect → account wedges at "connecting".
	 *   - Buddies: their presence has no "available" status object, so when the
	 *     prpl reports a contact online (purple_prpl_got_user_status(...,"available"))
	 *     the status can't be set → every contact shows OFFLINE even when online.
	 *
	 * The earlier fix removed + recreated the account, which freed its AIListContacts
	 * under Adium's contact list → dangling proxies (blank rows, crash on redraw).
	 * struct _PurpleAccount is exposed in account.h (not hidden), so instead we
	 * replicate what purple_account_new() does and attach/repair the presences in
	 * place — no account removal, no churn, no dangling references.
	 */
	PurpleAccount *acct = self.purpleAccount;
	PurplePlugin *prpl = acct ? purple_find_prpl([self protocolPlugin]) : NULL;
	PurplePluginProtocolInfo *info = prpl ? PURPLE_PLUGIN_PROTOCOL_INFO(prpl) : NULL;
	if (acct && info && info->status_types) {
		PurplePresence *pres = purple_account_get_presence(acct);
		BOOL accountHollow = (pres == NULL ||
		                      purple_presence_get_status(pres, "available") == NULL);

		/*
		 * Only (re)build the account's status types when its presence is actually
		 * hollow. A healthy account (created while the prpl was registered — e.g. a
		 * brand-new account) already has a presence whose PurpleStatus objects
		 * reference the current status types; calling purple_account_set_status_types
		 * again frees those types out from under the live statuses, and the
		 * set_status_active below then dereferences freed memory → crash.
		 */
		if (accountHollow) {
			purple_account_set_status_types(acct, info->status_types(acct));

			if (pres == NULL) {
				acct->presence = purple_presence_new_for_account(acct);
				pres = acct->presence;
			} else {
				purple_presence_add_list(pres, purple_prpl_get_statuses(acct, pres));
			}
			PurpleStatusType *avail =
				purple_account_get_status_type_with_primitive(acct, PURPLE_STATUS_AVAILABLE);
			purple_presence_set_status_active(pres,
				avail ? purple_status_type_get_id(avail) : "offline", TRUE);
		}

		/*
		 * Repair each buddy's hollow presence so incoming presence (ILN/NLN) can
		 * actually mark them online. Buddies added later (post-connect sync) build
		 * their presence with status types already set, so they're fine. Uses the
		 * account's (now valid) status types.
		 */
		GSList *buddies = purple_find_buddies(acct, NULL);
		for (GSList *l = buddies; l; l = l->next) {
			PurpleBuddy *b = (PurpleBuddy *)l->data;
			PurplePresence *bp = purple_buddy_get_presence(b);
			if (bp && purple_presence_get_status(bp, "available") == NULL)
				purple_presence_add_list(bp, purple_prpl_get_statuses(acct, bp));
		}
		g_slist_free(buddies);
	}

	[super configurePurpleAccount];
}

@end
