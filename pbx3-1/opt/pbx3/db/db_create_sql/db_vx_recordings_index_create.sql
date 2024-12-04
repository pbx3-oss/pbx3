BEGIN TRANSACTION;

/* s3_recording_index */
CREATE TABLE IF NOT EXISTS s3_recording_index (
id TEXT PRIMARY KEY,            -- s3 recording ksuid name
cluster text NOT NULL,          -- cluster ksuid          
caller_id text,
callee_id text,
agent text,
z_created datetime DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "s3inversion_cluster_index" on "s3inversion"("cluster");
CREATE INDEX "s3inversion_caller_id_index" on "s3inversion"("caller_id");
CREATE INDEX "s3inversion_callee_id_index" on "s3inversion"("callee_id");
CREATE INDEX "s3inversion_agent_index" on "s3inversion"("agent");
CREATE INDEX "s3inversion_created_index" on "s3inversion"("z_created");


COMMIT;