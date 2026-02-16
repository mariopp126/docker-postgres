-- =====================================================
-- AUTH SCHEMA
-- =====================================================

CREATE SCHEMA IF NOT EXISTS auth;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- USERS
-- =====================================================

CREATE TABLE auth.users (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

email VARCHAR(255) NOT NULL,
username VARCHAR(50),
password_hash TEXT NOT NULL,

is_active BOOLEAN NOT NULL DEFAULT TRUE,
is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
is_locked BOOLEAN NOT NULL DEFAULT FALSE,

failed_login_attempts INT NOT NULL DEFAULT 0,
last_login_at TIMESTAMPTZ,

created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
deleted_at TIMESTAMPTZ
);

ALTER TABLE auth.users
ADD CONSTRAINT uq_users_email UNIQUE (email);

CREATE INDEX idx_users_email ON auth.users(email);

-- =====================================================
-- ROLES
-- =====================================================

CREATE TABLE auth.roles (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
name VARCHAR(50) NOT NULL,
description TEXT,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE auth.roles
ADD CONSTRAINT uq_roles_name UNIQUE (name);

-- =====================================================
-- PERMISSIONS
-- =====================================================

CREATE TABLE auth.permissions (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
name VARCHAR(100) NOT NULL,
description TEXT,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE auth.permissions
ADD CONSTRAINT uq_permissions_name UNIQUE (name);

-- =====================================================
-- USER ROLES (many-to-many)
-- =====================================================

CREATE TABLE auth.user_roles (
user_id UUID NOT NULL,
role_id UUID NOT NULL,
assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),


CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id),
CONSTRAINT fk_user_roles_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
CONSTRAINT fk_user_roles_role
    FOREIGN KEY (role_id) REFERENCES auth.roles(id) ON DELETE CASCADE


);

-- =====================================================
-- ROLE PERMISSIONS
-- =====================================================

CREATE TABLE auth.role_permissions (
role_id UUID NOT NULL,
permission_id UUID NOT NULL,


CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
CONSTRAINT fk_role_permissions_role
    FOREIGN KEY (role_id) REFERENCES auth.roles(id) ON DELETE CASCADE,
CONSTRAINT fk_role_permissions_permission
    FOREIGN KEY (permission_id) REFERENCES auth.permissions(id) ON DELETE CASCADE


);

-- =====================================================
-- SESSIONS (active logins)
-- =====================================================

CREATE TABLE auth.sessions (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
user_id UUID NOT NULL,


ip_address INET,
user_agent TEXT,

created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
expires_at TIMESTAMPTZ NOT NULL,

is_revoked BOOLEAN NOT NULL DEFAULT FALSE,

CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE


);

CREATE INDEX idx_sessions_user_id ON auth.sessions(user_id);

-- =====================================================
-- REFRESH TOKENS (JWT)
-- =====================================================

CREATE TABLE auth.refresh_tokens (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
user_id UUID NOT NULL,
token_hash TEXT NOT NULL,


created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
expires_at TIMESTAMPTZ NOT NULL,
revoked_at TIMESTAMPTZ,

CONSTRAINT fk_refresh_tokens_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE


);

CREATE INDEX idx_refresh_tokens_user_id ON auth.refresh_tokens(user_id);

-- =====================================================
-- PASSWORD RESET
-- =====================================================

CREATE TABLE auth.password_resets (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
user_id UUID NOT NULL,
token_hash TEXT NOT NULL,
expires_at TIMESTAMPTZ NOT NULL,
used_at TIMESTAMPTZ,


CONSTRAINT fk_password_resets_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE


);

-- =====================================================
-- EMAIL VERIFICATION
-- =====================================================

CREATE TABLE auth.email_verifications (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
user_id UUID NOT NULL,
token_hash TEXT NOT NULL,
expires_at TIMESTAMPTZ NOT NULL,
verified_at TIMESTAMPTZ,


CONSTRAINT fk_email_verifications_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE

);

-- =====================================================
-- LOGIN ATTEMPTS (security / brute-force protection)
-- =====================================================

CREATE TABLE auth.login_attempts (
id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
email VARCHAR(255),
ip_address INET,
attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
was_successful BOOLEAN NOT NULL
);

CREATE INDEX idx_login_attempts_email ON auth.login_attempts(email);
CREATE INDEX idx_login_attempts_ip ON auth.login_attempts(ip_address);

-- =====================================================
-- REPORTING SCHEMA

CREATE SCHEMA IF NOT EXISTS reporting;

-- =========================
-- Categories
-- =========================
CREATE TABLE reporting.report_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

-- =========================
-- Status catalog
-- =========================
CREATE TABLE reporting.report_statuses (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

INSERT INTO reporting.report_statuses (code, name) VALUES
('submitted','Submitted'),
('received','Received'),
('in_review','In Review'),
('assigned','Assigned'),
('in_progress','In Progress'),
('resolved','Resolved'),
('rejected','Rejected');

-- =========================
-- Main Report
-- =========================
CREATE TABLE reporting.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    citizen_id UUID NOT NULL REFERENCES auth.users(id),

    category_id INT NOT NULL REFERENCES reporting.report_categories(id),
    status_id INT NOT NULL REFERENCES reporting.report_statuses(id),

    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP
);

-- =========================
-- Location (separated for maps later)
-- =========================
CREATE TABLE reporting.report_locations (
    report_id UUID PRIMARY KEY REFERENCES reporting.reports(id) ON DELETE CASCADE,

    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    address TEXT
);

-- =========================
-- Status history
-- =========================
CREATE TABLE reporting.report_status_history (
    id BIGSERIAL PRIMARY KEY,
    report_id UUID NOT NULL REFERENCES reporting.reports(id) ON DELETE CASCADE,
    status_id INT NOT NULL REFERENCES reporting.report_statuses(id),

    changed_by UUID REFERENCES auth.users(id),
    changed_at TIMESTAMP NOT NULL DEFAULT now(),
    comment TEXT
);

-- =========================
-- Assignment to institution user
-- =========================
CREATE TABLE reporting.report_assignments (
    id BIGSERIAL PRIMARY KEY,
    report_id UUID NOT NULL REFERENCES reporting.reports(id) ON DELETE CASCADE,
    assigned_to UUID NOT NULL REFERENCES auth.users(id),
    assigned_at TIMESTAMP NOT NULL DEFAULT now()
);


-- =========================
-- MEDIA SCHEMA (for report attachments)
CREATE SCHEMA IF NOT EXISTS media;

-- =========================
-- File Types
-- =========================
CREATE TABLE media.file_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    description VARCHAR(100)
);

INSERT INTO media.file_types (code, description) VALUES
('image','Photograph'),
('video','Video recording'),
('document','Attached document');

-- =========================
-- Files (generic storage reference)
-- =========================
CREATE TABLE media.files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    file_type_id INT NOT NULL REFERENCES media.file_types(id),

    original_name VARCHAR(255) NOT NULL,
    stored_name VARCHAR(255) NOT NULL UNIQUE,
    mime_type VARCHAR(100) NOT NULL,

    size_bytes BIGINT NOT NULL,

    storage_provider VARCHAR(50) NOT NULL,  -- local | s3 | minio
    storage_path TEXT NOT NULL,             -- path inside storage

    uploaded_by UUID REFERENCES auth.users(id),

    uploaded_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_files_uploaded_by ON media.files(uploaded_by);

-- =========================
-- Report Attachments
-- =========================
CREATE TABLE media.report_attachments (
    report_id UUID NOT NULL REFERENCES reporting.reports(id) ON DELETE CASCADE,
    file_id UUID NOT NULL REFERENCES media.files(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,

    PRIMARY KEY (report_id, file_id)
);


-- =========================
-- NOTIFICATIONS SCHEMA
-- =========================

CREATE SCHEMA IF NOT EXISTS notifications;

-- =========================
-- NOTIFICATION TYPES
-- =========================
CREATE TABLE IF NOT EXISTS notifications.notification_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL, 
    description TEXT
);

-- Seed values
INSERT INTO notifications.notification_types (code, description)
VALUES
    ('REPORT_CREATED', 'A citizen created a report'),
    ('REPORT_UPDATED', 'Report status changed'),
    ('PASSWORD_RESET', 'Password reset requested'),
    ('EMAIL_VERIFICATION', 'Verify email address')
ON CONFLICT (code) DO NOTHING;


-- =========================
-- USER NOTIFICATIONS
-- =========================
CREATE TABLE IF NOT EXISTS notifications.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,
    notification_type_id INT NOT NULL,

    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- FK → auth.users
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_user_notifications_user'
    ) THEN
        ALTER TABLE notifications.user_notifications
        ADD CONSTRAINT fk_user_notifications_user
        FOREIGN KEY (user_id)
        REFERENCES auth.users(id)
        ON DELETE CASCADE;
    END IF;
END$$;

-- FK → notification_types
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_user_notifications_type'
    ) THEN
        ALTER TABLE notifications.user_notifications
        ADD CONSTRAINT fk_user_notifications_type
        FOREIGN KEY (notification_type_id)
        REFERENCES notifications.notification_types(id);
    END IF;
END$$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_notifications_user
ON notifications.user_notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_user_notifications_unread
ON notifications.user_notifications(user_id, is_read);

-- =========================
-- RBAC SCHEMA
-- =========================

CREATE SCHEMA IF NOT EXISTS rbac;

-- =========================
-- ROLES
-- =========================
CREATE TABLE IF NOT EXISTS rbac.roles (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- default roles
INSERT INTO rbac.roles (code, name, description, is_system)
VALUES
    ('ADMIN', 'Administrator', 'Full system access', TRUE),
    ('STAFF', 'Municipal Staff', 'Manage citizen reports', TRUE),
    ('CITIZEN', 'Citizen', 'Create and track reports', TRUE)
ON CONFLICT (code) DO NOTHING;


-- =========================
-- PERMISSIONS
-- =========================
CREATE TABLE IF NOT EXISTS rbac.permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);

INSERT INTO rbac.permissions (code, description)
VALUES
    ('reports.create', 'Create reports'),
    ('reports.view.own', 'View own reports'),
    ('reports.view.all', 'View all reports'),
    ('reports.update.status', 'Update report status'),
    ('reports.assign', 'Assign report to staff'),
    ('users.manage', 'Manage users'),
    ('roles.manage', 'Manage roles and permissions')
ON CONFLICT (code) DO NOTHING;


-- =========================
-- ROLE PERMISSIONS
-- =========================
CREATE TABLE IF NOT EXISTS rbac.role_permissions (
    role_id INT NOT NULL,
    permission_id INT NOT NULL,
    PRIMARY KEY (role_id, permission_id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_role_permissions_role'
    ) THEN
        ALTER TABLE rbac.role_permissions
        ADD CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id)
        REFERENCES rbac.roles(id)
        ON DELETE CASCADE;
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_role_permissions_permission'
    ) THEN
        ALTER TABLE rbac.role_permissions
        ADD CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id)
        REFERENCES rbac.permissions(id)
        ON DELETE CASCADE;
    END IF;
END$$;


-- =========================
-- USER ROLES
-- =========================
CREATE TABLE IF NOT EXISTS rbac.user_roles (
    user_id UUID NOT NULL,
    role_id INT NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_roles_user'
    ) THEN
        ALTER TABLE rbac.user_roles
        ADD CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id)
        REFERENCES auth.users(id)
        ON DELETE CASCADE;
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_roles_role'
    ) THEN
        ALTER TABLE rbac.user_roles
        ADD CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id)
        REFERENCES rbac.roles(id)
        ON DELETE CASCADE;
    END IF;
END$$;


-- =========================
-- DEFAULT PERMISSION ASSIGNMENTS
-- =========================

-- CITIZEN permissions
INSERT INTO rbac.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM rbac.roles r, rbac.permissions p
WHERE r.code = 'CITIZEN'
AND p.code IN ('reports.create', 'reports.view.own')
ON CONFLICT DO NOTHING;

-- STAFF permissions
INSERT INTO rbac.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM rbac.roles r, rbac.permissions p
WHERE r.code = 'STAFF'
AND p.code IN ('reports.view.all','reports.update.status','reports.assign')
ON CONFLICT DO NOTHING;

-- ADMIN permissions
INSERT INTO rbac.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM rbac.roles r, rbac.permissions p
WHERE r.code = 'ADMIN'
ON CONFLICT DO NOTHING;


-- =========================
-- AUDIT SCHEMA
-- =========================

CREATE SCHEMA IF NOT EXISTS audit;

-- =========================
-- AUDIT LOG TABLE
-- =========================
CREATE TABLE IF NOT EXISTS audit.audit_logs (
    id BIGSERIAL PRIMARY KEY,

    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,

    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE

    old_data JSONB,
    new_data JSONB,

    changed_by UUID, -- user id (nullable for system actions)
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    ip_address INET,
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_audit_table_record
ON audit.audit_logs(table_name, record_id);

CREATE INDEX IF NOT EXISTS idx_audit_changed_by
ON audit.audit_logs(changed_by);


-- =========================
-- AUDIT FUNCTION
-- =========================
CREATE OR REPLACE FUNCTION audit.log_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
BEGIN

    -- get user id from session (set by backend later)
    BEGIN
        v_user_id := current_setting('app.current_user_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit.audit_logs (
            table_name,
            record_id,
            action,
            new_data,
            changed_by
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id::TEXT,
            'INSERT',
            to_jsonb(NEW),
            v_user_id
        );
        RETURN NEW;

    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            new_data,
            changed_by
        )
        VALUES (
            TG_TABLE_NAME,
            NEW.id::TEXT,
            'UPDATE',
            to_jsonb(OLD),
            to_jsonb(NEW),
            v_user_id
        );
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            changed_by
        )
        VALUES (
            TG_TABLE_NAME,
            OLD.id::TEXT,
            'DELETE',
            to_jsonb(OLD),
            v_user_id
        );
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- USERS
DROP TRIGGER IF EXISTS trg_audit_users ON auth.users;
CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION audit.log_changes();

-- REPORTS
DROP TRIGGER IF EXISTS trg_audit_reports ON reporting.reports;
CREATE TRIGGER trg_audit_reports
AFTER INSERT OR UPDATE OR DELETE
ON reporting.reports
FOR EACH ROW
EXECUTE FUNCTION audit.log_changes();

-- USER ROLES
DROP TRIGGER IF EXISTS trg_audit_user_roles ON rbac.user_roles;
CREATE TRIGGER trg_audit_user_roles
AFTER INSERT OR UPDATE OR DELETE
ON rbac.user_roles
FOR EACH ROW
EXECUTE FUNCTION audit.log_changes();
