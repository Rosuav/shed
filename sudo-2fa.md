Backup sudo access with 2fa protection
======================================

Goals:

* Have a primary account that has sudo access with minimal hassles
  - May or may not have a password; access is customarily by SSH key.
  - Has passwordless unlimited sudo access
  - Must not be compromised
* Have a secondary account for support access
  - Has a password which may be known to multiple people (but not the world)
  - Connecting via this account leads to the log viewer only (no shell)
  - Can use sudo but only with a 2FA token
  - The TOTP shared secret is controlled by the owner of the primary account
* It should be reasonably innocuous to log in to the secondary account w/o 2FA

Demo VM on Sikorsky (with no world access):
* Primary account: rosuav / large-early-druid-guys
* Secondary account: support / news-learned-sorry-natural
