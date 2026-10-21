-- Instance vs tenant concurrency help (CALL_CONCURRENCY_LIMITS_REQUIREMENTS).
-- Safe to re-run. INSERT OR IGNORE alone does not refresh existing htext.

UPDATE tt_help_core
SET displayname = 'Max inbound calls',
    htext = 'Maximum concurrent inbound calls allowed on this instance (shared across all tenants). Often set to the upstream provider limit. 0 or empty = unlimited.'
WHERE pkey = 'maxin';

UPDATE tt_help_core
SET displayname = 'Max outbound calls',
    htext = 'Maximum concurrent outbound calls allowed on this instance (shared across all tenants). Often set to the upstream provider limit. 0 or empty = unlimited.'
WHERE pkey = 'maxout';

INSERT OR IGNORE INTO tt_help_core(pkey, displayname, htext) VALUES (
  'tenant_maxin',
  'Max inbound calls',
  'Maximum concurrent inbound calls allowed for this tenant. Instance Max in also applies; the stricter limit wins. 0 or empty = unlimited.'
);
UPDATE tt_help_core
SET displayname = 'Max inbound calls',
    htext = 'Maximum concurrent inbound calls allowed for this tenant. Instance Max in also applies; the stricter limit wins. 0 or empty = unlimited.'
WHERE pkey = 'tenant_maxin';

INSERT OR IGNORE INTO tt_help_core(pkey, displayname, htext) VALUES (
  'tenant_maxout',
  'Max outbound calls',
  'Maximum concurrent outbound calls allowed for this tenant. Instance Max out also applies; the stricter limit wins. 0 or empty = unlimited.'
);
UPDATE tt_help_core
SET displayname = 'Max outbound calls',
    htext = 'Maximum concurrent outbound calls allowed for this tenant. Instance Max out also applies; the stricter limit wins. 0 or empty = unlimited.'
WHERE pkey = 'tenant_maxout';
