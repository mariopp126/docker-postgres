-- =====================================================
-- AUTH SCHEMA
-- =====================================================

CREATE SCHEMA IF NOT EXISTS auth;

-- UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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
