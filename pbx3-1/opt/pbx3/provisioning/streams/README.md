# Vendor-grain provision stream fragments (Phase A).
#
# Resolved by #INCLUDE <name> from ipphone.provision (and nested includes).
# No Device table. No per-SKU matrix. BLF templates (*.Fkey / *.Lkey) are skipped.
#
# Seeded: Yealink + Snom (A2). Typical extension.provision:
#   #INCLUDE yealink.Extension
#   #INCLUDE snom.Extension
#
# Placeholders: $ext $password $desc $registrar $localip $bindport $tlsport
#   $provurl $padminpass $puserpass + LDAP tokens (see ProvisionKernel).
