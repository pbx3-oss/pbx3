BEGIN TRANSACTION;

/* Customer_index */
CREATE TABLE IF NOT EXISTS Customers (
customer text PRIMARY KEY,          -- customer ksuid
cname text,
z_created datetime DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Instances (
instance text PRIMARY KEY,          -- instance ksuid
cname text,
z_created datetime DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Clusters (
cluster text PRIMARY KEY,          -- cluster ksuid
cname text,
z_created datetime DEFAULT CURRENT_TIMESTAMP
);

/* InstanceCluster_index */
CREATE TABLE IF NOT EXISTS InstanceCluster (
instance text,          -- instance ksuid
cluster text,           -- culster ksuid 
z_created datetime DEFAULT CURRENT_TIMESTAMP,
PRIMARY KEY (instance,cluster)
);

CREATE INDEX "s3inversion_instance_index" on "s3inversion"("instance");
CREATE INDEX "s3inversion_cluster_index" on "s3inversion"("clusterd");

/* CustomerCluster_index */
CREATE TABLE IF NOT EXISTS CustomerCluster (
customer text,          -- instance ksuid
cluster text,           -- culster ksuid 
z_created datetime DEFAULT CURRENT_TIMESTAMP,
PRIMARY KEY (instance,cluster)
);

CREATE INDEX "s3inversion_customer_index" on "s3inversion"("customer");
CREATE INDEX "s3inversion_cluster_index" on "s3inversion"("clusterd");
COMMIT;

