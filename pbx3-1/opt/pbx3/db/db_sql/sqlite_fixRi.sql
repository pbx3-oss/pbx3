-- NB!!!!
-- this transformation is NOT idempotent.  You may only run it ONCE
-- as part of a sark V6 migration to pbx3
--

UPDATE agent SET cname = name;
UPDATE agent SET cluster = (SELECT shortuid FROM cluster WHERE pkey = agent.cluster);

UPDATE appl SET cname = name;
UPDATE appl SET cluster = (SELECT shortuid FROM cluster WHERE pkey = appl.cluster);

UPDATE cos SET cname = pkey;
UPDATE cos SET cluster = (SELECT shortuid FROM cluster WHERE pkey = cos.cluster);

UPDATE greeting SET cname = pkey; 
UPDATE greeting SET cluster = (SELECT shortuid FROM cluster WHERE pkey = greeting.cluster);

UPDATE ipphone SET cluster = (SELECT shortuid FROM cluster WHERE pkey = ipphone.cluster);

UPDATE ivrmenu SET cname = name;
UPDATE ivrmenu SET cluster = (SELECT shortuid FROM cluster WHERE pkey = ivrmenu.cluster);

UPDATE inroutes SET cluster = (SELECT shortuid FROM cluster WHERE pkey = inroutes.cluster);

UPDATE trunks SET cluster = (SELECT shortuid FROM cluster WHERE pkey = trunks.cluster);

UPDATE meetme SET cluster = (SELECT shortuid FROM cluster WHERE pkey = meetme.cluster);

UPDATE queue SET cluster = (SELECT shortuid FROM cluster WHERE pkey = queue.cluster );

UPDATE route SET cluster = (SELECT shortuid FROM cluster WHERE pkey = route.cluster);
