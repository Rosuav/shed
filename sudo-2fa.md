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

IMPORTANT NOTE: pam_google_authenticator.so assumes that all 2FA codes are
(at most) six digits long. Using longer codes results in inexplicable failures.

As the user that will be guarded, run:
    google-authenticator -tDf -Q NONE -u -W -e 1

In order to guard just one group, add the following lines to /etc/pam.d/sudo:
    auth sufficient pam_succeed_if.so user notingroup sudo2fa
    auth required pam_google_authenticator.so

Alternatively, use the "nullok" parameter to the Google Authenticator plugin
to allow it to quietly ignore 2FA on any user that does not have it set up.

To have the shared secret not be visible to the user who uses it, move the
.google_authenticator file into a root-owned directory:

    sudo mkdir -p /etc/2fa -m 700
    sudo mv ~support/.google_authenticator /etc/2fa/support
    sudo chown root: /etc/2fa/support

Then tell the module to look there:

    auth required pam_google_authenticator.so user=root secret=/etc/2fa/${USER}

To ensure that the support user doesn't have "normal" shell access:

    sudo chsh -s /home/rosuav/shed/logviewer.py support
