-- =========================================================================
-- 1. 基础环境与配置指标自查
-- =========================================================================
-- 如果 ecommerce 库尚未创建，请先执行下面这行（如果在控制台执行，请确保已切换至 ecommerce 库）
-- CREATE DATABASE ecommerce;

SHOW wal_level;                    -- 预期输出: logical
SHOW work_mem;                     -- 预期输出: 4854kB
SHOW max_replication_slots;        -- 预期输出: 5
SHOW max_wal_senders;              -- 预期输出: 5

-- =========================================================================
-- 2. 创建并配置流复制专属用户 (最小特权原则：拒绝 SUPERUSER，仅限流复制)
-- =========================================================================
DO $$
    BEGIN
        -- 2.1 检查并创建角色（如果不存在）
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'debezium_user') THEN
            CREATE ROLE debezium_user WITH LOGIN PASSWORD 'msdnmm' REPLICATION;
        ELSE
            -- 2.2 如果已存在，强制修正其核心属性（剥离超级用户，保留登录与流复制）
            ALTER USER debezium_user WITH NOSUPERUSER REPLICATION LOGIN;
        END IF;
    END $$;

-- =========================================================================
-- 3. 数据库级与全局所有 Schema 自动化精准赋权（已重构升级）
-- =========================================================================

-- 3.1 赋予数据库级核心权限 (Debezium 自动创建 publication 和逻辑复制槽所需的必要权限)
GRANT CONNECT, CREATE ON DATABASE ecommerce TO debezium_user;

-- 3.2 治理系统 public Schema 权限
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;

-- 3.3 自动循环：治理当前所有已存在的自定义 Schema（如 orders, products 等）
DO $$
    DECLARE
        schema_rec RECORD;
    BEGIN
        FOR schema_rec IN
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'public')
              AND schema_name NOT LIKE 'pg_toast%'
              AND schema_name NOT LIKE 'pg_temp%'
            LOOP
                -- A. 赋予 Schema 使用权与临时创建追踪元素权
                EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO debezium_user;', schema_rec.schema_name);

                -- B. 赋予该 Schema 下当前已有表的完整 DML 权限（满足 CDC 监测与信号表交互）
                EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO debezium_user;', schema_rec.schema_name);
                EXECUTE format('GRANT SELECT, USAGE ON ALL SEQUENCES IN SCHEMA %I TO debezium_user;', schema_rec.schema_name);

                -- C. 核心补丁：确保该 Schema 内未来新创建的表，也能被自动赋予权限
                EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO debezium_user;', schema_rec.schema_name);
                EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, USAGE ON SEQUENCES TO debezium_user;', schema_rec.schema_name);

                RAISE NOTICE '已成功处理当前已存 Schema [%] 的全局动态赋权。', schema_rec.schema_name;
            END LOOP;
    END $$;

-- 3.4 终极防御：创建事件触发器，确保【未来新建的任意 Schema】自动继承上述权限
CREATE OR REPLACE FUNCTION public.tg_grant_debezium_on_new_schema()
    RETURNS event_trigger AS $$
DECLARE
    obj RECORD;
BEGIN
    -- 捕获所有新创建的 Schema
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE object_type = 'schema'
        LOOP
            -- 排除系统 Schema
            IF obj.object_identity NOT IN ('pg_catalog', 'information_schema', 'public')
                AND obj.object_identity NOT LIKE 'pg_toast%'
                AND obj.object_identity NOT LIKE 'pg_temp%' THEN

                EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO debezium_user;', obj.object_identity);
                EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO debezium_user;', obj.object_identity);
                EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, USAGE ON SEQUENCES TO debezium_user;', obj.object_identity);

                RAISE NOTICE '事件触发器成功介入：已自动为新 Schema [%] 补齐 debezium_user 权限。', obj.object_identity;
            END IF;
        END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 绑定事件触发器（若已存在则先删除，防止重复创建）
DROP EVENT TRIGGER IF EXISTS trg_auto_grant_new_schema;
CREATE EVENT TRIGGER trg_auto_grant_new_schema
    ON ddl_command_end
    WHEN tag IN ('CREATE SCHEMA')
EXECUTE FUNCTION public.tg_grant_debezium_on_new_schema();

-- =========================================================================
-- 4. 严谨的闭环自动化审计验证
-- =========================================================================

-- 验证项 A：核心流复制属性验证
-- 预期输出：(debezium_user, true) -> 证明其具备原生免 Role 约束的槽管理权
SELECT rolname, rolreplication
FROM pg_authid
WHERE rolname = 'debezium_user';

-- 验证项 B：角色继承关系验证（防污染审计）
-- 预期输出：返回 0 行数据 -> 彻底证明系统中没有挂载任何残存、报错的过时预定义 Role
SELECT m.rolname AS member_role, g.rolname AS group_role
FROM pg_auth_members am
         JOIN pg_roles m ON am.member = m.oid
         JOIN pg_roles g ON am.roleid = g.oid
WHERE m.rolname = 'debezium_user';
