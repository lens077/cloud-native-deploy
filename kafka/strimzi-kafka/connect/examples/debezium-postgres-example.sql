
SHOW wal_level;
SHOW work_mem;

SELECT * FROM pg_create_logical_replication_slot('debezium_slot', 'wal2json');

CREATE ROLE debezium_user WITH LOGIN PASSWORD 'msdnmm' REPLICATION;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;

-- 授予复制和超级用户权限（或至少复制 + 数据库所有者）
ALTER USER debezium_user WITH REPLICATION SUPERUSER;

-- 授予对特定数据库的连接和创建复制槽的权限
GRANT CONNECT ON DATABASE ecommerce TO debezium_user;
GRANT CREATE ON DATABASE ecommerce TO debezium_user;

-- 确保对要捕获的表有 SELECT 权限
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;

-- 1. 确认 debezium_user 拥有 LOGIN 和 REPLICATION 属性
ALTER USER debezium_user WITH REPLICATION LOGIN;

-- 2. 授予预定义角色（允许创建逻辑复制槽）
GRANT pg_create_logical_replication_slot TO debezium_user;

-- 3. 允许连接数据库
GRANT CONNECT ON DATABASE ecommerce TO debezium_user;

-- 4. 如果需要自动创建 publication (pgoutput 插件)，还需要 CREATE 权限
GRANT CREATE ON DATABASE ecommerce TO debezium_user;

-- 5. 确保对捕获表的读权限
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;

SHOW max_wal_senders;
SHOW max_replication_slots;

SELECT * FROM pg_replication_slots;
SELECT * FROM pg_stat_replication;
