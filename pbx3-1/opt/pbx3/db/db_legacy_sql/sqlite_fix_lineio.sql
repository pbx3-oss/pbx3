-- NB!!!!
-- Split the old lineio into trunks and inbound routes
-- Drop the old lineio table
--

INSERT INTO inroutes SELECT * from lineio where technology = "DiD" or technology = "CLiD" or technology = "Class";
INSERT INTO trunks SELECT * from lineio where technology = "SIP" or technology = "IAX2";
DROP TABLE IF EXISTS lineio;