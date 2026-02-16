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
