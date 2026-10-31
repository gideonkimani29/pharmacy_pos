package store

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const schema = `
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  phone TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL CHECK (role IN ('admin', 'pharmacist', 'cashier')),
  password_hash TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  last_sign_in_at TEXT
);
CREATE TABLE IF NOT EXISTS refresh_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS medicines (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  generic_name TEXT NOT NULL DEFAULT '',
  dosage_form TEXT NOT NULL,
  sku TEXT NOT NULL UNIQUE,
  barcode TEXT NOT NULL DEFAULT '',
  selling_price_minor INTEGER NOT NULL CHECK (selling_price_minor >= 0),
  reorder_level INTEGER NOT NULL CHECK (reorder_level >= 0),
  requires_prescription INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS medicines_barcode_idx ON medicines(barcode);
CREATE TABLE IF NOT EXISTS suppliers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT
);
CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL DEFAULT '',
  credit_limit_minor INTEGER NOT NULL DEFAULT 0 CHECK (credit_limit_minor >= 0),
  balance_minor INTEGER NOT NULL DEFAULT 0 CHECK (balance_minor >= 0),
  active INTEGER NOT NULL DEFAULT 1,
  last_purchase_on TEXT
);
CREATE TABLE IF NOT EXISTS batches (
  id TEXT PRIMARY KEY,
  medicine_id TEXT NOT NULL REFERENCES medicines(id),
  batch_number TEXT NOT NULL,
  supplier_name TEXT NOT NULL DEFAULT '',
  received_on TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  quantity_received INTEGER NOT NULL CHECK (quantity_received >= 0),
  quantity_on_hand INTEGER NOT NULL CHECK (quantity_on_hand >= 0),
  unit_cost_minor INTEGER NOT NULL CHECK (unit_cost_minor >= 0),
  selling_price_minor INTEGER NOT NULL CHECK (selling_price_minor >= 0)
);
CREATE INDEX IF NOT EXISTS batches_fefo_idx ON batches(medicine_id, expiry_date, quantity_on_hand);
CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  receipt_number TEXT NOT NULL UNIQUE,
  idempotency_key TEXT NOT NULL UNIQUE,
  request_hash TEXT NOT NULL,
  customer_id TEXT REFERENCES customers(id),
  sale_type TEXT NOT NULL,
  subtotal_minor INTEGER NOT NULL,
  discount_minor INTEGER NOT NULL,
  total_minor INTEGER NOT NULL,
  change_due_minor INTEGER NOT NULL DEFAULT 0,
  amount_on_account_minor INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sale_lines (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id),
  medicine_id TEXT NOT NULL REFERENCES medicines(id),
  batch_id TEXT NOT NULL REFERENCES batches(id),
  quantity INTEGER NOT NULL,
  unit_price_minor INTEGER NOT NULL,
  unit_cost_minor INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sale_payments (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL REFERENCES sales(id),
  method TEXT NOT NULL,
  amount_minor INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS purchases (
  id TEXT PRIMARY KEY,
  reference TEXT NOT NULL UNIQUE,
  idempotency_key TEXT NOT NULL UNIQUE,
  request_hash TEXT NOT NULL,
  supplier_id TEXT REFERENCES suppliers(id),
  invoice_number TEXT NOT NULL,
  received_on TEXT NOT NULL,
  payment_status TEXT NOT NULL,
  total_minor INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS purchase_lines (
  id TEXT PRIMARY KEY,
  purchase_id TEXT NOT NULL REFERENCES purchases(id),
  medicine_id TEXT NOT NULL REFERENCES medicines(id),
  batch_id TEXT NOT NULL REFERENCES batches(id),
  quantity INTEGER NOT NULL,
  unit_cost_minor INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id TEXT PRIMARY KEY,
  batch_id TEXT NOT NULL REFERENCES batches(id),
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,
  reason TEXT NOT NULL,
  note TEXT NOT NULL,
  adjusted_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS account_payments (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES customers(id),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  method TEXT NOT NULL,
  reference TEXT,
  received_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  value_json TEXT NOT NULL
);
`

func Migrate(db *sql.DB) error {
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("apply database schema: %w", err)
	}
	return nil
}

func EnsureDatabaseDirectory(path string) error {
	if path == ":memory:" || strings.HasPrefix(path, "file:") {
		return nil
	}
	dir := filepath.Dir(path)
	if dir == "." || dir == "" {
		return nil
	}
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return fmt.Errorf("create database directory: %w", err)
	}
	return nil
}
