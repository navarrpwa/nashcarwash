-- ============================================================
-- QuickWash Enterprise — Complete Supabase Setup
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- DROP EXISTING TABLES (safe re-run)
-- ============================================================
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sms_logs CASCADE;
DROP TABLE IF EXISTS cctv_detections CASCADE;
DROP TABLE IF EXISTS cctv_cameras CASCADE;
DROP TABLE IF EXISTS loyalty_history CASCADE;
DROP TABLE IF EXISTS visit_reward_rules CASCADE;
DROP TABLE IF EXISTS offer_redemptions CASCADE;
DROP TABLE IF EXISTS offers CASCADE;
DROP TABLE IF EXISTS packages CASCADE;
DROP TABLE IF EXISTS purchase_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS service_log_edits CASCADE;
DROP TABLE IF EXISTS service_log_payments CASCADE;
DROP TABLE IF EXISTS service_log_services CASCADE;
DROP TABLE IF EXISTS service_logs CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS customer_plates CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS inventory_products CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS wash_service_prices CASCADE;
DROP TABLE IF EXISTS wash_services CASCADE;
DROP TABLE IF EXISTS vehicle_categories CASCADE;
DROP TABLE IF EXISTS vehicle_types CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS user_permissions CASCADE;
DROP TABLE IF EXISTS app_users CASCADE;

-- ============================================================
-- CORE AUTH TABLES
-- ============================================================

CREATE TABLE app_users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('admin','manager','staff')),
  active        BOOLEAN NOT NULL DEFAULT true,
  last_login    TIMESTAMPTZ,
  login_attempts INT NOT NULL DEFAULT 0,
  locked_until  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_sessions (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  token        TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32),'hex'),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '8 hours'),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address   TEXT,
  user_agent   TEXT
);

CREATE TABLE user_permissions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  module     TEXT NOT NULL,
  can_view   BOOLEAN NOT NULL DEFAULT false,
  can_create BOOLEAN NOT NULL DEFAULT false,
  can_edit   BOOLEAN NOT NULL DEFAULT false,
  can_delete BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(user_id, module)
);

-- ============================================================
-- APP CONFIGURATION
-- ============================================================

CREATE TABLE app_config (
  key   TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_methods (
  id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code     TEXT UNIQUE NOT NULL,
  label    TEXT NOT NULL,
  icon     TEXT NOT NULL DEFAULT '💳',
  enabled  BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0
);

-- ============================================================
-- VEHICLE TYPES & CATEGORIES
-- ============================================================

CREATE TABLE vehicle_types (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code       TEXT UNIQUE NOT NULL,
  label      TEXT NOT NULL,
  icon       TEXT NOT NULL DEFAULT '🚗',
  sort_order INT NOT NULL DEFAULT 0,
  active     BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE vehicle_categories (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_type_id UUID NOT NULL REFERENCES vehicle_types(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  multiplier      NUMERIC(5,2) NOT NULL DEFAULT 1.0,
  sort_order      INT NOT NULL DEFAULT 0,
  active          BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(vehicle_type_id, name)
);

-- ============================================================
-- WASH SERVICES & PRICING
-- ============================================================

CREATE TABLE wash_services (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT UNIQUE NOT NULL,
  category     TEXT NOT NULL DEFAULT 'basic'
               CHECK (category IN ('basic','premium','detailing','extra')),
  base_price   NUMERIC(10,2) NOT NULL DEFAULT 0,
  duration_min INT NOT NULL DEFAULT 30,
  active       BOOLEAN NOT NULL DEFAULT true,
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE wash_service_prices (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id          UUID NOT NULL REFERENCES wash_services(id) ON DELETE CASCADE,
  vehicle_category_id UUID NOT NULL REFERENCES vehicle_categories(id) ON DELETE CASCADE,
  price               NUMERIC(10,2) NOT NULL DEFAULT 0,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(service_id, vehicle_category_id)
);

-- ============================================================
-- SUPPLIERS & INVENTORY
-- ============================================================

CREATE TABLE suppliers (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  contact     TEXT,
  phone       TEXT,
  email       TEXT,
  address     TEXT,
  outstanding NUMERIC(10,2) NOT NULL DEFAULT 0,
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory_products (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  sku           TEXT UNIQUE,
  barcode       TEXT,
  category      TEXT NOT NULL DEFAULT 'accessories',
  brand         TEXT,
  supplier_id   UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  cost_price    NUMERIC(10,2) NOT NULL DEFAULT 0,
  selling_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  stock         INT NOT NULL DEFAULT 0,
  min_stock     INT NOT NULL DEFAULT 5,
  max_stock     INT NOT NULL DEFAULT 100,
  unit          TEXT NOT NULL DEFAULT 'pcs',
  active        BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- STAFF & ATTENDANCE
-- ============================================================

CREATE TABLE staff (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  phone       TEXT,
  role        TEXT NOT NULL DEFAULT 'Staff',
  basic       NUMERIC(10,2) NOT NULL DEFAULT 0,
  hra         NUMERIC(10,2) NOT NULL DEFAULT 0,
  allowances  NUMERIC(10,2) NOT NULL DEFAULT 0,
  join_date   DATE,
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE attendance (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  staff_id   UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  date       DATE NOT NULL,
  status     TEXT NOT NULL DEFAULT 'absent'
             CHECK (status IN ('present','absent','half-day','leave')),
  in_time    TEXT,
  out_time   TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(staff_id, date)
);

-- ============================================================
-- CUSTOMERS
-- ============================================================

CREATE TABLE customers (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  phone        TEXT NOT NULL,
  email        TEXT,
  visits       INT NOT NULL DEFAULT 0,
  total_spent  NUMERIC(10,2) NOT NULL DEFAULT 0,
  last_visit   TIMESTAMPTZ,
  points       INT NOT NULL DEFAULT 0,
  notes        TEXT,
  active       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customer_plates (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  plate       TEXT NOT NULL,
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(customer_id, plate)
);

CREATE INDEX idx_customer_plates_plate ON customer_plates(UPPER(plate));

-- ============================================================
-- PACKAGES & OFFERS
-- ============================================================

CREATE TABLE packages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  price       NUMERIC(10,2) NOT NULL DEFAULT 0,
  discount    NUMERIC(10,2) NOT NULL DEFAULT 0,
  validity    INT NOT NULL DEFAULT 30,
  active      BOOLEAN NOT NULL DEFAULT true,
  services    JSONB NOT NULL DEFAULT '[]',
  categories  JSONB NOT NULL DEFAULT '[]',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE offers (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  type         TEXT NOT NULL DEFAULT 'percentage'
               CHECK (type IN ('percentage','fixed','bogo','happy_hour','weekend','festival','coupon')),
  value        NUMERIC(10,2) NOT NULL DEFAULT 0,
  start_date   DATE,
  end_date     DATE,
  coupon       TEXT,
  usage_limit  INT NOT NULL DEFAULT 0,
  used_count   INT NOT NULL DEFAULT 0,
  services     JSONB NOT NULL DEFAULT '[]',
  categories   JSONB NOT NULL DEFAULT '[]',
  packages_ref JSONB NOT NULL DEFAULT '[]',
  eligibility  TEXT NOT NULL DEFAULT 'all',
  active       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PURCHASE ORDERS
-- ============================================================

CREATE TABLE purchase_orders (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_number    TEXT UNIQUE NOT NULL,
  supplier_id  UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  total        NUMERIC(10,2) NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','ordered','received','cancelled')),
  paid         BOOLEAN NOT NULL DEFAULT false,
  notes        TEXT,
  created_by   UUID REFERENCES app_users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE purchase_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES inventory_products(id),
  qty         INT NOT NULL DEFAULT 1,
  unit_cost   NUMERIC(10,2) NOT NULL DEFAULT 0,
  total       NUMERIC(10,2) GENERATED ALWAYS AS (qty * unit_cost) STORED
);

-- ============================================================
-- EXPENSES & TRANSACTIONS
-- ============================================================

CREATE TABLE expenses (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category   TEXT NOT NULL,
  amount     NUMERIC(10,2) NOT NULL,
  date       DATE NOT NULL DEFAULT CURRENT_DATE,
  notes      TEXT,
  created_by UUID REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE transactions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  receipt_no  TEXT UNIQUE NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('wash','product')),
  plate       TEXT,
  services    JSONB NOT NULL DEFAULT '[]',
  total       NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment     TEXT NOT NULL DEFAULT 'cash',
  status      TEXT NOT NULL DEFAULT 'completed',
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  created_by  UUID REFERENCES app_users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SERVICE LOGS (Core Operations)
-- ============================================================

CREATE TABLE service_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_number      TEXT UNIQUE NOT NULL,
  invoice_no      TEXT UNIQUE NOT NULL,
  plate           TEXT NOT NULL,
  model           TEXT,
  vehicle_type_id UUID REFERENCES vehicle_types(id),
  vehicle_cat_id  UUID REFERENCES vehicle_categories(id),
  customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,
  amount          NUMERIC(10,2) NOT NULL DEFAULT 0,
  discount        NUMERIC(10,2) NOT NULL DEFAULT 0,
  tax             NUMERIC(10,2) NOT NULL DEFAULT 0,
  total           NUMERIC(10,2) GENERATED ALWAYS AS
                  (GREATEST(0, amount - discount + tax)) STORED,
  status          TEXT NOT NULL DEFAULT 'waiting'
                  CHECK (status IN ('waiting','received','washing','interior',
                                    'detailing','qc','ready','delivered','cancelled')),
  pay_method      TEXT,
  paid            BOOLEAN NOT NULL DEFAULT false,
  pts_earned      INT NOT NULL DEFAULT 0,
  pts_redeemed    INT NOT NULL DEFAULT 0,
  estimated_mins  INT,
  staff_name      TEXT,
  notes           TEXT,
  sms_status      TEXT,
  entered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  received_at     TIMESTAMPTZ,
  washing_at      TIMESTAMPTZ,
  interior_at     TIMESTAMPTZ,
  detailing_at    TIMESTAMPTZ,
  qc_at           TIMESTAMPTZ,
  ready_at        TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  created_by      UUID REFERENCES app_users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE service_log_services (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  log_id         UUID NOT NULL REFERENCES service_logs(id) ON DELETE CASCADE,
  service_id     UUID REFERENCES wash_services(id) ON DELETE SET NULL,
  service_name   TEXT NOT NULL,
  price          NUMERIC(10,2) NOT NULL DEFAULT 0,
  qty            INT NOT NULL DEFAULT 1
);

CREATE TABLE service_log_payments (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  log_id     UUID NOT NULL REFERENCES service_logs(id) ON DELETE CASCADE,
  method     TEXT NOT NULL,
  amount     NUMERIC(10,2) NOT NULL DEFAULT 0,
  notes      TEXT,
  paid_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE service_log_edits (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  log_id      UUID NOT NULL REFERENCES service_logs(id) ON DELETE CASCADE,
  edited_by   TEXT NOT NULL,
  action      TEXT NOT NULL,
  prev_value  JSONB,
  new_value   JSONB,
  edited_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- LOYALTY
-- ============================================================

CREATE TABLE visit_reward_rules (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  visits     INT NOT NULL,
  reward     TEXT NOT NULL,
  active     BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE loyalty_history (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  action      TEXT NOT NULL CHECK (action IN ('earned','redeemed')),
  points      INT NOT NULL,
  total_value NUMERIC(10,2),
  log_id      UUID REFERENCES service_logs(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CCTV / ANPR
-- ============================================================

CREATE TABLE cctv_cameras (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  location   TEXT,
  ip         TEXT,
  type       TEXT NOT NULL DEFAULT 'custom',
  api_key    TEXT,
  enabled    BOOLEAN NOT NULL DEFAULT true,
  status     TEXT NOT NULL DEFAULT 'offline',
  last_ping  TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cctv_detections (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  plate       TEXT NOT NULL,
  camera_id   UUID REFERENCES cctv_cameras(id) ON DELETE SET NULL,
  camera_name TEXT,
  location    TEXT,
  confidence  INT NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'detected'
              CHECK (status IN ('detected','ignored','linked')),
  log_id      UUID REFERENCES service_logs(id) ON DELETE SET NULL,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cctv_detections_plate ON cctv_detections(plate);
CREATE INDEX idx_cctv_detections_at ON cctv_detections(detected_at DESC);

-- ============================================================
-- SMS LOGS
-- ============================================================

CREATE TABLE sms_logs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  log_id     UUID REFERENCES service_logs(id) ON DELETE SET NULL,
  phone      TEXT NOT NULL,
  message    TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending','sent','failed','sending')),
  attempts   INT NOT NULL DEFAULT 0,
  sent_at    TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AUDIT LOGS
-- ============================================================

CREATE TABLE audit_logs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID REFERENCES app_users(id) ON DELETE SET NULL,
  user_name  TEXT,
  action     TEXT NOT NULL,
  module     TEXT NOT NULL,
  record_id  TEXT,
  prev_value JSONB,
  new_value  JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_service_logs_plate ON service_logs(plate);
CREATE INDEX idx_service_logs_status ON service_logs(status);
CREATE INDEX idx_service_logs_entered ON service_logs(entered_at DESC);
CREATE INDEX idx_service_logs_customer ON service_logs(customer_id);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX idx_attendance_staff_date ON attendance(staff_id, date);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_sessions_token ON user_sessions(token);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);

-- ============================================================
-- DATABASE FUNCTIONS
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_service_logs_updated    BEFORE UPDATE ON service_logs    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_customers_updated       BEFORE UPDATE ON customers        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_inventory_updated       BEFORE UPDATE ON inventory_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_purchase_orders_updated BEFORE UPDATE ON purchase_orders  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_attendance_updated      BEFORE UPDATE ON attendance        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated           BEFORE UPDATE ON app_users         FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Secure session verification
CREATE OR REPLACE FUNCTION verify_session(p_token TEXT)
RETURNS TABLE(user_id UUID, user_name TEXT, role TEXT, active BOOLEAN) AS $$
BEGIN
  -- Clean expired sessions
  DELETE FROM user_sessions WHERE expires_at < NOW();
  RETURN QUERY
    SELECT u.id, u.name, u.role, u.active
    FROM user_sessions s
    JOIN app_users u ON u.id = s.user_id
    WHERE s.token = p_token AND s.expires_at > NOW() AND u.active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Login function (returns session token)
CREATE OR REPLACE FUNCTION login(p_email TEXT, p_password TEXT, p_ip TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user app_users%ROWTYPE;
  v_token TEXT;
BEGIN
  SELECT * INTO v_user FROM app_users
  WHERE email = LOWER(p_email) AND active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid credentials');
  END IF;

  -- Check account lockout
  IF v_user.locked_until IS NOT NULL AND v_user.locked_until > NOW() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Account temporarily locked');
  END IF;

  -- Verify password
  IF v_user.password_hash != crypt(p_password, v_user.password_hash) THEN
    UPDATE app_users SET login_attempts = login_attempts + 1,
      locked_until = CASE WHEN login_attempts >= 4 THEN NOW() + INTERVAL '15 minutes' ELSE NULL END
    WHERE id = v_user.id;
    RETURN jsonb_build_object('success', false, 'message', 'Invalid credentials');
  END IF;

  -- Reset attempts, create session
  UPDATE app_users SET login_attempts = 0, locked_until = NULL, last_login = NOW()
  WHERE id = v_user.id;

  INSERT INTO user_sessions(user_id, ip_address, expires_at)
  VALUES (v_user.id, p_ip, NOW() + INTERVAL '8 hours')
  RETURNING token INTO v_token;

  RETURN jsonb_build_object(
    'success', true,
    'token', v_token,
    'user', jsonb_build_object('id', v_user.id, 'name', v_user.name,
                                'email', v_user.email, 'role', v_user.role)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get next job number
CREATE OR REPLACE FUNCTION next_job_number()
RETURNS TEXT AS $$
DECLARE v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM service_logs;
  RETURN 'JOB-' || LPAD((v_count + 1)::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Get next PO number
CREATE OR REPLACE FUNCTION next_po_number()
RETURNS TEXT AS $$
DECLARE v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM purchase_orders;
  RETURN 'PO-' || LPAD((v_count + 1)::TEXT, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Complete vehicle entry (atomic transaction)
CREATE OR REPLACE FUNCTION create_service_entry(p_data JSONB, p_session_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID; v_user_name TEXT; v_role TEXT; v_active BOOLEAN;
  v_log_id UUID; v_job TEXT; v_invoice TEXT;
  v_svc JSONB; v_pts INT; v_cust_id UUID;
BEGIN
  -- Verify session
  SELECT user_id, user_name, role, active INTO v_user_id, v_user_name, v_role, v_active
  FROM verify_session(p_session_token);
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Session expired'); END IF;

  v_job     := next_job_number();
  v_invoice := 'INV-' || LPAD((SELECT COUNT(*)+1 FROM service_logs)::TEXT, 6,'0');
  v_cust_id := (p_data->>'customer_id')::UUID;

  -- Insert main log
  INSERT INTO service_logs(
    job_number, invoice_no, plate, model,
    vehicle_type_id, vehicle_cat_id, customer_id,
    amount, discount, tax, status, pay_method, paid,
    pts_earned, pts_redeemed, estimated_mins, staff_name, notes,
    entered_at, created_by
  ) VALUES (
    v_job, v_invoice,
    p_data->>'plate', p_data->>'model',
    (p_data->>'vehicle_type_id')::UUID, (p_data->>'vehicle_cat_id')::UUID,
    v_cust_id,
    (p_data->>'amount')::NUMERIC, (p_data->>'discount')::NUMERIC, 0,
    'waiting', p_data->>'pay_method',
    (p_data->>'paid')::BOOLEAN,
    (p_data->>'pts_earned')::INT, (p_data->>'pts_redeemed')::INT,
    (p_data->>'estimated_mins')::INT, p_data->>'staff_name', p_data->>'notes',
    NOW(), v_user_id
  ) RETURNING id INTO v_log_id;

  -- Insert services
  FOR v_svc IN SELECT * FROM jsonb_array_elements(p_data->'services') LOOP
    INSERT INTO service_log_services(log_id, service_id, service_name, price, qty)
    VALUES (v_log_id,
            (v_svc->>'service_id')::UUID,
            v_svc->>'service_name',
            (v_svc->>'price')::NUMERIC,
            COALESCE((v_svc->>'qty')::INT, 1));
  END LOOP;

  -- Insert payment details
  FOR v_svc IN SELECT * FROM jsonb_array_elements(p_data->'payment_details') LOOP
    INSERT INTO service_log_payments(log_id, method, amount)
    VALUES (v_log_id, v_svc->>'method', (v_svc->>'amount')::NUMERIC);
  END LOOP;

  -- Update customer loyalty points
  IF v_cust_id IS NOT NULL AND (p_data->>'pts_earned')::INT > 0 THEN
    UPDATE customers SET
      points = points + (p_data->>'pts_earned')::INT - COALESCE((p_data->>'pts_redeemed')::INT, 0),
      visits = visits + 1,
      total_spent = total_spent + (p_data->>'amount')::NUMERIC,
      last_visit = NOW()
    WHERE id = v_cust_id;

    INSERT INTO loyalty_history(customer_id, action, points, total_value, log_id)
    VALUES (v_cust_id, 'earned', (p_data->>'pts_earned')::INT,
            (p_data->>'amount')::NUMERIC, v_log_id);

    IF COALESCE((p_data->>'pts_redeemed')::INT, 0) > 0 THEN
      INSERT INTO loyalty_history(customer_id, action, points, total_value, log_id)
      VALUES (v_cust_id, 'redeemed', (p_data->>'pts_redeemed')::INT,
              (p_data->>'amount')::NUMERIC, v_log_id);
    END IF;
  END IF;

  -- Add plate to customer if not already there
  IF v_cust_id IS NOT NULL THEN
    INSERT INTO customer_plates(customer_id, plate)
    VALUES (v_cust_id, p_data->>'plate')
    ON CONFLICT DO NOTHING;
  END IF;

  -- Audit log
  INSERT INTO audit_logs(user_id, user_name, action, module, record_id, new_value)
  VALUES (v_user_id, v_user_name, 'CREATE', 'service_log', v_log_id::TEXT, p_data);

  RETURN jsonb_build_object('success', true, 'log_id', v_log_id,
                             'job_number', v_job, 'invoice_no', v_invoice);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Advance service log status
CREATE OR REPLACE FUNCTION advance_log_status(
  p_log_id UUID, p_status TEXT, p_session_token TEXT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID; v_user_name TEXT; v_role TEXT; v_active BOOLEAN;
  v_log service_logs%ROWTYPE;
  v_col TEXT;
BEGIN
  SELECT user_id, user_name, role, active INTO v_user_id, v_user_name, v_role, v_active
  FROM verify_session(p_session_token);
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Session expired'); END IF;

  SELECT * INTO v_log FROM service_logs WHERE id = p_log_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Log not found'); END IF;

  -- Block delivery without payment
  IF p_status = 'delivered' AND NOT v_log.paid THEN
    RETURN jsonb_build_object('success',false,'message','Payment required before delivery');
  END IF;

  v_col := CASE p_status
    WHEN 'received'  THEN 'received_at'
    WHEN 'washing'   THEN 'washing_at'
    WHEN 'interior'  THEN 'interior_at'
    WHEN 'detailing' THEN 'detailing_at'
    WHEN 'qc'        THEN 'qc_at'
    WHEN 'ready'     THEN 'ready_at'
    WHEN 'delivered' THEN 'delivered_at'
    WHEN 'cancelled' THEN 'cancelled_at'
    ELSE NULL
  END;

  EXECUTE format('UPDATE service_logs SET status = $1, %I = NOW(), updated_at = NOW() WHERE id = $2', v_col)
  USING p_status, p_log_id;

  INSERT INTO service_log_edits(log_id, edited_by, action, prev_value, new_value)
  VALUES (p_log_id, v_user_name, 'status_change',
          jsonb_build_object('status', v_log.status),
          jsonb_build_object('status', p_status));

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record payment
CREATE OR REPLACE FUNCTION record_payment(p_data JSONB, p_session_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID; v_user_name TEXT; v_role TEXT; v_active BOOLEAN;
  v_log service_logs%ROWTYPE;
  v_pm JSONB; v_pts INT; v_cust_id UUID;
BEGIN
  SELECT user_id, user_name, role, active INTO v_user_id, v_user_name, v_role, v_active
  FROM verify_session(p_session_token);
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Session expired'); END IF;

  SELECT * INTO v_log FROM service_logs WHERE id = (p_data->>'log_id')::UUID;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Log not found'); END IF;

  -- Insert payment records
  FOR v_pm IN SELECT * FROM jsonb_array_elements(p_data->'payment_details') LOOP
    INSERT INTO service_log_payments(log_id, method, amount, notes)
    VALUES ((p_data->>'log_id')::UUID, v_pm->>'method',
            (v_pm->>'amount')::NUMERIC, p_data->>'notes');
  END LOOP;

  -- Update log
  UPDATE service_logs SET
    paid = true,
    pay_method = p_data->>'pay_method',
    pts_earned = COALESCE((p_data->>'pts_earned')::INT, 0),
    updated_at = NOW()
  WHERE id = (p_data->>'log_id')::UUID;

  -- Award loyalty points
  v_cust_id := v_log.customer_id;
  v_pts := COALESCE((p_data->>'pts_earned')::INT, 0);

  IF v_cust_id IS NOT NULL AND v_pts > 0 THEN
    UPDATE customers SET
      points = points + v_pts,
      total_spent = total_spent + v_log.total,
      last_visit = NOW()
    WHERE id = v_cust_id;

    INSERT INTO loyalty_history(customer_id, action, points, total_value, log_id)
    VALUES (v_cust_id, 'earned', v_pts, v_log.total, v_log.id);
  END IF;

  INSERT INTO service_log_edits(log_id, edited_by, action)
  VALUES (v_log.id, v_user_name, 'payment_recorded');

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Receive purchase order (updates stock)
CREATE OR REPLACE FUNCTION receive_purchase_order(p_po_id UUID, p_session_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID; v_user_name TEXT; v_role TEXT; v_active BOOLEAN;
  v_item purchase_items%ROWTYPE;
BEGIN
  SELECT user_id, user_name, role, active INTO v_user_id, v_user_name, v_role, v_active
  FROM verify_session(p_session_token);
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','Session expired'); END IF;

  -- Update each product stock
  FOR v_item IN SELECT * FROM purchase_items WHERE order_id = p_po_id LOOP
    UPDATE inventory_products SET
      stock = stock + v_item.qty,
      cost_price = v_item.unit_cost,
      updated_at = NOW()
    WHERE id = v_item.product_id;
  END LOOP;

  UPDATE purchase_orders SET status = 'received', updated_at = NOW() WHERE id = p_po_id;

  INSERT INTO audit_logs(user_id, user_name, action, module, record_id)
  VALUES (v_user_id, v_user_name, 'RECEIVE_PO', 'purchases', p_po_id::TEXT);

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Dashboard stats (server-side aggregation)
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_week  DATE := CURRENT_DATE - 7;
BEGIN
  RETURN jsonb_build_object(
    'today_revenue', (
      SELECT COALESCE(SUM(total),0) FROM service_logs
      WHERE paid = true AND DATE(entered_at) = v_today
    ),
    'today_txns', (SELECT COUNT(*) FROM service_logs WHERE DATE(entered_at) = v_today),
    'week_revenue', (
      SELECT COALESCE(SUM(total),0) FROM service_logs
      WHERE paid = true AND entered_at >= v_week
    ),
    'active_jobs', (
      SELECT COUNT(*) FROM service_logs
      WHERE status NOT IN ('delivered','cancelled')
    ),
    'waiting', (SELECT COUNT(*) FROM service_logs WHERE status = 'waiting'),
    'delivered_today', (
      SELECT COUNT(*) FROM service_logs
      WHERE status = 'delivered' AND DATE(entered_at) = v_today
    ),
    'low_stock', (
      SELECT COUNT(*) FROM inventory_products WHERE stock <= min_stock AND active = true
    ),
    'detected_today', (
      SELECT COUNT(*) FROM cctv_detections WHERE DATE(detected_at) = v_today
    ),
    'weekly_revenue_chart', (
      SELECT jsonb_agg(jsonb_build_object('date', day, 'revenue', rev))
      FROM (
        SELECT DATE(entered_at) AS day, COALESCE(SUM(total),0) AS rev
        FROM service_logs
        WHERE entered_at >= v_week AND paid = true
        GROUP BY DATE(entered_at) ORDER BY day
      ) d
    ),
    'payment_split', (
      SELECT jsonb_agg(jsonb_build_object('method', pay_method, 'count', cnt))
      FROM (
        SELECT pay_method, COUNT(*) AS cnt
        FROM service_logs WHERE pay_method IS NOT NULL
        GROUP BY pay_method
      ) p
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_service_logs_full AS
SELECT
  sl.*,
  c.name AS customer_name, c.phone AS customer_phone,
  vt.label AS vehicle_type_label, vt.icon AS vehicle_type_icon,
  vc.name AS vehicle_cat_name,
  (SELECT jsonb_agg(jsonb_build_object('service_name', sls.service_name, 'price', sls.price, 'qty', sls.qty))
   FROM service_log_services sls WHERE sls.log_id = sl.id) AS services,
  (SELECT jsonb_agg(jsonb_build_object('method', slp.method, 'amount', slp.amount))
   FROM service_log_payments slp WHERE slp.log_id = sl.id) AS payment_details,
  (SELECT jsonb_agg(jsonb_build_object('by', sle.edited_by, 'action', sle.action, 'at', sle.edited_at)
           ORDER BY sle.edited_at)
   FROM service_log_edits sle WHERE sle.log_id = sl.id) AS edit_history
FROM service_logs sl
LEFT JOIN customers c ON c.id = sl.customer_id
LEFT JOIN vehicle_types vt ON vt.id = sl.vehicle_type_id
LEFT JOIN vehicle_categories vc ON vc.id = sl.vehicle_cat_id;

CREATE OR REPLACE VIEW v_customers_full AS
SELECT
  c.*,
  COALESCE(
    (SELECT jsonb_agg(cp.plate) FROM customer_plates cp WHERE cp.customer_id = c.id),
    '[]'::jsonb
  ) AS plates
FROM customers c;

CREATE OR REPLACE VIEW v_inventory_full AS
SELECT
  p.*,
  s.name AS supplier_name,
  (p.cost_price * p.stock) AS stock_value
FROM inventory_products p
LEFT JOIN suppliers s ON s.id = p.supplier_id;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE app_users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers          ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_products ENABLE ROW LEVEL SECURITY;

-- All tables accessible via anon key (auth handled by app)
CREATE POLICY "anon_access" ON app_users         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_access" ON user_sessions      FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_access" ON service_logs       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_access" ON customers          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_access" ON inventory_products FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- SEED DATA
-- ============================================================

-- App Configuration
INSERT INTO app_config(key, value) VALUES
  ('biz_name',       '"QuickWash"'),
  ('biz_phone',      '"+91 98765 43210"'),
  ('biz_addr',       '"Car Wash Center, Main Road"'),
  ('gst_rate',       '18'),
  ('currency',       '"₹"'),
  ('points_per_rupee','0.1'),
  ('point_value',    '0.1'),
  ('point_expiry',   '365'),
  ('loyalty_enabled','true'),
  ('sms_enabled',    'true'),
  ('sms_provider',   '"demo"'),
  ('sms_sender_id',  '"QWASH"'),
  ('sms_retry',      '2'),
  ('sms_auto_on_delivery', 'true'),
  ('sms_auto_on_payment',  'true'),
  ('cctv_dedup_mins',  '5'),
  ('cctv_min_conf',    '75'),
  ('cctv_retention',   '30'),
  ('cctv_scan_interval','3')
ON CONFLICT(key) DO UPDATE SET value = EXCLUDED.value;

-- Payment Methods
INSERT INTO payment_methods(code, label, icon, enabled, sort_order) VALUES
  ('cash',   'Cash',          '💵', true, 1),
  ('card',   'Card',          '💳', true, 2),
  ('upi',    'UPI',           '📱', true, 3),
  ('bank',   'Bank Transfer', '🏦', true, 4),
  ('wallet', 'Mobile Wallet', '👛', true, 5),
  ('credit', 'Pay After Wash','📋', true, 6)
ON CONFLICT(code) DO NOTHING;

-- Admin user (password: admin123)
INSERT INTO app_users(name, email, password_hash, role) VALUES
  ('Admin User',    'admin@quickwash.qa',
   crypt('admin123', gen_salt('bf')), 'admin'),
  ('Khalid Hassan', 'staff@quickwash.qa',
   crypt('staff123', gen_salt('bf')), 'staff')
ON CONFLICT(email) DO NOTHING;

-- Vehicle Types
INSERT INTO vehicle_types(code, label, icon, sort_order) VALUES
  ('2w',    '2 Wheeler', '🛵', 1),
  ('3w',    '3 Wheeler', '🛺', 2),
  ('4w',    '4 Wheeler', '🚗', 3),
  ('truck', 'Truck',     '🚛', 4),
  ('bus',   'Bus',       '🚌', 5),
  ('van',   'Van',       '🚐', 6),
  ('other', 'Other',     '🚙', 7)
ON CONFLICT(code) DO NOTHING;

-- Vehicle Categories
DO $$
DECLARE
  v2w UUID; v3w UUID; v4w UUID; vtruck UUID; vbus UUID; vvan UUID; vother UUID;
BEGIN
  SELECT id INTO v2w    FROM vehicle_types WHERE code='2w';
  SELECT id INTO v3w    FROM vehicle_types WHERE code='3w';
  SELECT id INTO v4w    FROM vehicle_types WHERE code='4w';
  SELECT id INTO vtruck FROM vehicle_types WHERE code='truck';
  SELECT id INTO vbus   FROM vehicle_types WHERE code='bus';
  SELECT id INTO vvan   FROM vehicle_types WHERE code='van';
  SELECT id INTO vother FROM vehicle_types WHERE code='other';

  INSERT INTO vehicle_categories(vehicle_type_id, name, multiplier, sort_order) VALUES
    (v2w,'Scooter',0.6,1),(v2w,'Motorcycle',0.7,2),
    (v3w,'Auto Rickshaw',0.7,1),
    (v4w,'Sedan',1.0,1),(v4w,'Hatchback',0.9,2),(v4w,'SUV',1.3,3),
    (v4w,'Coupe',1.0,4),(v4w,'Pickup',1.3,5),(v4w,'Luxury',1.6,6),
    (vtruck,'Light Truck',1.7,1),(vtruck,'Heavy Truck',2.0,2),
    (vbus,'Standard Bus',2.2,1),(vbus,'Minibus',1.7,2),
    (vvan,'Van',1.4,1),(vvan,'Minivan',1.2,2),
    (vother,'Other',1.0,1)
  ON CONFLICT DO NOTHING;
END $$;

-- Wash Services
INSERT INTO wash_services(name, category, base_price, duration_min, sort_order) VALUES
  ('Exterior Wash',     'basic',     150, 20, 1),
  ('Interior Clean',    'basic',     200, 30, 2),
  ('Full Wash',         'basic',     300, 45, 3),
  ('Premium Wash',      'premium',   500, 60, 4),
  ('Engine Clean',      'premium',   400, 45, 5),
  ('Paint Polish',      'detailing', 800, 90, 6),
  ('Full Detail',       'detailing',1200,120, 7),
  ('Ceramic Coat',      'detailing',3500,180, 8),
  ('Odour Removal',     'extra',     600, 40, 9),
  ('Tyre Shine',        'extra',      80, 10,10),
  ('Dashboard Polish',  'extra',     120, 15,11),
  ('Headlight Polish',  'extra',     250, 20,12)
ON CONFLICT(name) DO NOTHING;

-- Suppliers
INSERT INTO suppliers(name, contact, phone, email, address, outstanding) VALUES
  ('AutoCare Distributors','Raj Kumar',  '9876001234','raj@autocare.com', 'Industrial Area, Phase 2', 0),
  ('CarChem India Ltd',    'Priya Sharma','9876005678','priya@carchem.com','Chemical Zone, Sector 5',  2800),
  ('Detailing Pro Supplies','Ahmed Khan', '9876009012','ahmed@detpro.com', 'Trade Center, Block C',    0)
ON CONFLICT DO NOTHING;

-- Inventory Products
DO $$
DECLARE s1 UUID; s2 UUID;
BEGIN
  SELECT id INTO s1 FROM suppliers WHERE name='AutoCare Distributors';
  SELECT id INTO s2 FROM suppliers WHERE name='CarChem India Ltd';
  INSERT INTO inventory_products(name,sku,barcode,category,brand,supplier_id,cost_price,selling_price,stock,min_stock,max_stock,unit) VALUES
    ('Air Freshener',       'AF001','1001','accessories','Ambi Pur',s1,80,150,45,10,100,'pcs'),
    ('Wiper Blade Set',     'WB002','1002','accessories','Bosch',   s1,220,450,12,5,50,'set'),
    ('Car Shampoo 500ml',   'CS003','1003','supplies',  '3M',      s2,130,280,3,10,80,'bottle'),
    ('Polish Kit',          'PK004','1004','supplies',  'Meguiars',s2,350,750,8,5,40,'kit'),
    ('Microfiber Cloth 3pc','MC005','1005','supplies',  'Generic', s2,120,320,0,10,100,'pack'),
    ('Tyre Shine Spray',    'TS006','1006','supplies',  'WD-40',   s2,160,350,18,8,60,'bottle'),
    ('Dashboard Wax',       'DW007','1007','accessories','Turtle Wax',s1,100,220,22,5,50,'bottle')
  ON CONFLICT(sku) DO NOTHING;
END $$;

-- Staff
INSERT INTO staff(name, phone, role, basic, hra, allowances, join_date) VALUES
  ('Khalid Hassan', '9876543211','Senior Washer',15000,3000,2000,'2024-01-15'),
  ('Fatima Ali',    '9876543212','Cashier',       12000,2400,1600,'2024-03-01'),
  ('Mohammed Raza', '9876543213','Detailer',      18000,3600,2400,'2023-11-10'),
  ('Priya Kumar',   '9876543214','Helper',        10000,2000,1000,'2025-02-20')
ON CONFLICT DO NOTHING;

-- Packages
INSERT INTO packages(name, description, price, discount, validity, active, services, categories) VALUES
  ('Silver Package','Basic exterior care',200,30,30,true,
   '["Exterior Wash","Tyre Shine"]','["Sedan","Hatchback","SUV"]'),
  ('Gold Package','Complete interior & exterior',450,70,30,true,
   '["Full Wash","Interior Clean","Dashboard Polish"]','["Sedan","SUV","Hatchback","Luxury"]'),
  ('Premium Package','Full premium detailing',1800,200,60,true,
   '["Full Detail","Engine Clean","Tyre Shine","Odour Removal"]','["SUV","Luxury","Sedan"]')
ON CONFLICT DO NOTHING;

-- Offers
INSERT INTO offers(name,type,value,start_date,end_date,services,categories,active,coupon,usage_limit,used_count) VALUES
  ('Weekend Special','percentage',15,'2025-07-19','2025-07-27',
   '["Exterior Wash","Full Wash"]','[]',true,'',0,23),
  ('SUV Discount','fixed',200,'2025-07-01','2025-07-31',
   '[]','["SUV"]',true,'SUVOFF',50,12),
  ('Happy Hour','percentage',20,'2025-07-01','2025-07-31',
   '["Exterior Wash","Interior Clean"]','[]',false,'',0,8)
ON CONFLICT DO NOTHING;

-- Visit Reward Rules
INSERT INTO visit_reward_rules(visits, reward, active) VALUES
  (5,  '1 Free Exterior Wash', true),
  (10, 'Premium Wash Free',    true)
ON CONFLICT DO NOTHING;

-- CCTV Cameras
INSERT INTO cctv_cameras(name, location, ip, type, enabled, status) VALUES
  ('Entry Gate Cam','Main Entrance','192.168.1.101','hikvision',true,'online'),
  ('Bay 1 Camera',  'Wash Bay 1',   '192.168.1.102','dahua',    true,'online'),
  ('Exit Gate Cam', 'Exit',         '192.168.1.103','axis',     false,'offline')
ON CONFLICT DO NOTHING;

-- Customers
INSERT INTO customers(name, phone, email, visits, total_spent, points, notes) VALUES
  ('Ali Hassan',    '9876500001','ali@ex.com',  5, 3200,320,'VIP'),
  ('Sara Mansoori', '9876500002','',            3, 1800,180,''),
  ('Noor Ahmed',    '9876500003','noor@ex.com', 8, 6400,640,'Premium')
ON CONFLICT DO NOTHING;

DO $$
DECLARE c1 UUID; c2 UUID; c3 UUID;
BEGIN
  SELECT id INTO c1 FROM customers WHERE phone='9876500001';
  SELECT id INTO c2 FROM customers WHERE phone='9876500002';
  SELECT id INTO c3 FROM customers WHERE phone='9876500003';
  INSERT INTO customer_plates(customer_id, plate) VALUES
    (c1,'KL07AB0001'),(c2,'KL10C1234'),(c3,'MH12AB3456')
  ON CONFLICT DO NOTHING;
END $$;

-- Seed Service Logs
DO $$
DECLARE
  c1 UUID; c2 UUID;
  vcat_suv UUID; vcat_hatch UUID;
  vtype_4w UUID;
  svc_premium UUID; svc_tyre UUID; svc_full UUID;
  log1 UUID; log2 UUID;
BEGIN
  SELECT id INTO c1      FROM customers WHERE phone='9876500001';
  SELECT id INTO c2      FROM customers WHERE phone='9876500002';
  SELECT id INTO vtype_4w FROM vehicle_types WHERE code='4w';
  SELECT id INTO vcat_suv   FROM vehicle_categories WHERE name='SUV';
  SELECT id INTO vcat_hatch FROM vehicle_categories WHERE name='Hatchback';
  SELECT id INTO svc_premium FROM wash_services WHERE name='Premium Wash';
  SELECT id INTO svc_tyre    FROM wash_services WHERE name='Tyre Shine';
  SELECT id INTO svc_full    FROM wash_services WHERE name='Full Wash';

  INSERT INTO service_logs(job_number,invoice_no,plate,model,vehicle_type_id,vehicle_cat_id,
    customer_id,amount,discount,tax,status,pay_method,paid,pts_earned,staff_name,notes,
    entered_at,received_at,washing_at)
  VALUES('JOB-000001','INV-000001','KL07AB0001','Fortuner Toyota',vtype_4w,vcat_suv,
    c1,690,0,0,'washing','cash',false,0,'Khalid Hassan','VIP customer',
    NOW()-INTERVAL '35 minutes',NOW()-INTERVAL '30 minutes',NOW()-INTERVAL '20 minutes')
  RETURNING id INTO log1;

  INSERT INTO service_log_services(log_id,service_id,service_name,price,qty)
  VALUES (log1,svc_premium,'Premium Wash',650,1),(log1,svc_tyre,'Tyre Shine',80,1);

  INSERT INTO service_logs(job_number,invoice_no,plate,model,vehicle_type_id,vehicle_cat_id,
    customer_id,amount,discount,tax,status,pay_method,paid,pts_earned,staff_name,
    entered_at,received_at,washing_at,qc_at,ready_at)
  VALUES('JOB-000002','INV-000002','KL10C1234','Fronx Suzuki',vtype_4w,vcat_hatch,
    c2,270,0,0,'ready','upi',true,27,'Mohammed Raza',
    NOW()-INTERVAL '90 minutes',NOW()-INTERVAL '88 minutes',
    NOW()-INTERVAL '80 minutes',NOW()-INTERVAL '10 minutes',NOW()-INTERVAL '5 minutes')
  RETURNING id INTO log2;

  INSERT INTO service_log_services(log_id,service_id,service_name,price,qty)
  VALUES (log2,svc_full,'Full Wash',270,1);

  INSERT INTO service_log_payments(log_id,method,amount)
  VALUES (log2,'upi',270);
END $$;

-- Seed Expenses
INSERT INTO expenses(category, amount, date, notes) VALUES
  ('supplies',     1200, CURRENT_DATE - 5,  'Cleaning supplies'),
  ('salaries',     8000, CURRENT_DATE - 2,  'Monthly salaries'),
  ('rent',         3500, CURRENT_DATE - 1,  'Monthly rent'),
  ('utilities',     600, CURRENT_DATE,      'Electricity bill'),
  ('maintenance',   400, CURRENT_DATE - 10, 'Equipment maintenance')
ON CONFLICT DO NOTHING;

-- ============================================================
-- REALTIME PUBLICATIONS
-- ============================================================

DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE
  service_logs,
  service_log_services,
  service_log_payments,
  cctv_detections,
  customers,
  inventory_products,
  attendance;

-- ============================================================
-- DONE
-- ============================================================
SELECT 'QuickWash Supabase setup complete! Tables: ' ||
  (SELECT COUNT(*) FROM information_schema.tables
   WHERE table_schema = 'public' AND table_type = 'BASE TABLE')::TEXT ||
  ' Functions: ' ||
  (SELECT COUNT(*) FROM information_schema.routines
   WHERE routine_schema = 'public')::TEXT AS result;
