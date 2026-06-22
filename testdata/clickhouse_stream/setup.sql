CREATE DATABASE IF NOT EXISTS sw_asdb;

DROP TABLE IF EXISTS sw_asdb.access_local;

CREATE TABLE sw_asdb.access_local (
    id          String,
    ts          DateTime,
    ts_ms       Int64,
    sid         String,
    uid         String,
    ip          IPv4,
    host        String,
    url         String,
    method      String,
    status      UInt16,
    channel     String,
    ua          String,
    result      String,
    result_action String,
    req_risk    Array(String),
    resp_content_length UInt32,
    node_ip     String
) ENGINE = MergeTree()
ORDER BY (ts, host)
PARTITION BY toYYYYMMDD(ts);
