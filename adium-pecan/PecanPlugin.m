#import "PecanPlugin.h"
#import "PecanService.h"

/*
 * Static init entry point exported by libmsn-pecan.a (built with
 * -DSTATIC_PECAN). It builds the PurplePlugin, runs init, and calls
 * purple_plugin_register() — no gmodule/dlopen required, which matters
 * because Adium's libpurple is built with --disable-plugins.
 *
 * Declared as returning int to avoid pulling in glib here; gboolean is gint.
 */
extern int purple_init_msn_pecan_plugin(void);

@implementation PecanPlugin

- (void)installPlugin
{
	[PecanService registerService];
}

- (void)uninstallPlugin
{
}

- (void)installLibpurplePlugin
{
	/*
	 * Register the prpl as early as possible. Adium auto-connects restored
	 * accounts during startup; if the prpl isn't registered by then, the
	 * connect silently wedges the account in a permanent "connecting" state.
	 * installLibpurplePlugin runs earlier than loadLibpurplePlugin.
	 */
	purple_init_msn_pecan_plugin();
}

- (void)loadLibpurplePlugin
{
}

@end
