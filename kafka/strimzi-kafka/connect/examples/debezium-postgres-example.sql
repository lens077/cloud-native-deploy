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
-- 3. 数据库级与微服务 Schema 级精准赋权
-- =========================================================================

-- 3.1 赋予数据库级核心权限 (Debezium 自动创建 publication 和逻辑复制槽所需的必要权限)
GRANT CONNECT, CREATE ON DATABASE ecommerce TO debezium_user;

-- 3.2 治理系统 public Schema 权限
GRANT USAGE ON SCHEMA public TO debezium_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium_user;

-- 3.3 治理业务订单 orders Schema 权限 (带有动态防御的动态 SQL)
DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'orders') THEN
            -- 允许读取 Schema 结构与临时创建追踪元素
            GRANT USAGE, CREATE ON SCHEMA orders TO debezium_user;

            -- 精准赋予基础 DML 权限（Debezium 进行 CDC 监测以及信号表交互所需的完整生命周期权限）
            GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA orders TO debezium_user;

            -- 核心补丁：确保未来在 orders 架构中新开的表，Debezium 也能自动化捕获，防止权限断代
            ALTER DEFAULT PRIVILEGES IN SCHEMA orders GRANT SELECT ON TABLES TO debezium_user;
        END IF;
    END $$;

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
