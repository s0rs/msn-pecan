#import "PecanAccount.h"
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

- (void)configurePurpleAccount
{
	/*
	 * Populate the login server / port if they're empty.
	 *
	 * The prpl declares defaults (msnmsgr.escargot.chat / 1863) on its "server"
	 * and "port" account options, but Adium's account-setup UI doesn't pre-fill
	 * those option defaults — it stores an empty string / 0 when the user leaves
	 * the fields blank. purple_account_get_string(acct,"server",<default>) then
	 * returns that stored "" rather than the default, so a freshly-added account
	 * tries to connect to an empty host. Fill them in here so a new account
	 * connects to Escargot with no manual setup.
	 */
	PurpleAccount *acct = self.purpleAccount;
	if (acct) {
		const char *server = purple_account_get_string(acct, "server", "");
		if (!server || !*server)
			purple_account_set_string(acct, "server", "msnmsgr.escargot.chat");
		if (purple_account_get_int(acct, "port", 0) == 0)
			purple_account_set_int(acct, "port", 1863);
	}

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
	PurplePlugin *prpl = acct ? purple_find_prpl([self protocolPlugin]) : NULL;
	PurplePluginProtocolInfo *info = prpl ? PURPLE_PLUGIN_PROTOCOL_INFO(prpl) : NULL;
	if (acct && info && info->status_types) {
		/* Status types must exist before any presence can be given real statuses. */
		purple_account_set_status_types(acct, info->status_types(acct));

		/* Account presence. */
		PurplePresence *pres = purple_account_get_presence(acct);
		if (pres == NULL) {
			acct->presence = purple_presence_new_for_account(acct);
			pres = acct->presence;
		} else if (purple_presence_get_status(pres, "available") == NULL) {
			purple_presence_add_list(pres, purple_prpl_get_statuses(acct, pres));
		}
		PurpleStatusType *avail =
			purple_account_get_status_type_with_primitive(acct, PURPLE_STATUS_AVAILABLE);
		purple_presence_set_status_active(pres,
			avail ? purple_status_type_get_id(avail) : "offline", TRUE);

		/*
		 * Repair each buddy's hollow presence so incoming presence (ILN/NLN) can
		 * actually mark them online. Buddies added later (post-connect sync) build
		 * their presence with status types already set, so they're fine.
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
