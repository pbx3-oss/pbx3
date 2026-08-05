-- Day-parts help text (slice E). Safe on live + new.
UPDATE tt_help_core SET displayname='Master force', htext='Master hard-force (BLF/API). AUTO = follow day-parts schedule (timer sched_mode + route profiles). CLOSED forces closed routing and wins over holidays. Multi-mode force uses AstDB OCSTAT mode tokens; *30*/*31* still AUTO/CLOSED.' WHERE pkey='masterclose';
UPDATE tt_help_core SET displayname='Timer State (legacy)', htext='Legacy OPEN/CLOSED mirror of sched_mode for dual-read. Prefer Schedule mode for multi-mode day parts.' WHERE pkey='oclo';
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sched_mode','Schedule mode','Current day-parts mode written by the timer (open, closed, lunch, …). Inbound routing uses this with route profiles. Operator CLOSED force overrides it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('route_profile','Route profile','Tenant map of schedule mode to destination for this DID. Preferred over separate open/close columns when set.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('entry_dest','Always route','Optional fixed destination: skip schedule and always send the call here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mode','Day timer mode','Mode asserted when this day-timer window matches (e.g. closed, lunch). Higher priority wins on overlap.');
