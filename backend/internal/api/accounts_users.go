package api

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type customerAccountDTO struct {
	ID             string  `json:"id"`
	Name           string  `json:"name"`
	Phone          string  `json:"phone"`
	Email          string  `json:"email"`
	CreditLimit    int64   `json:"creditLimitMinor"`
	Balance        int64   `json:"balanceMinor"`
	Active         bool    `json:"isActive"`
	LastPurchaseOn *string `json:"lastPurchaseOn"`
}

func scanCustomerAccount(row scanner) (customerAccountDTO, error) {
	var item customerAccountDTO
	var active int
	err := row.Scan(&item.ID, &item.Name, &item.Phone, &item.Email, &item.CreditLimit, &item.Balance, &active, &item.LastPurchaseOn)
	item.Active = active != 0
	return item, err
}

func (s *Server) listCustomerAccounts(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, name, phone, email, credit_limit_minor, balance_minor, active, last_purchase_on
		FROM customers ORDER BY name LIMIT 1000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customer accounts.", nil)
		return
	}
	defer rows.Close()
	items := make([]customerAccountDTO, 0)
	for rows.Next() {
		item, err := scanCustomerAccount(rows)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customer accounts.", nil)
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customer accounts.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

type customerDraft struct {
	Name             string `json:"name"`
	Phone            string `json:"phone"`
	Email            string `json:"email"`
	CreditLimitMinor int64  `json:"creditLimitMinor"`
}

func validCustomerDraft(input customerDraft) bool {
	return strings.TrimSpace(input.Name) != "" && strings.TrimSpace(input.Phone) != "" && input.CreditLimitMinor >= 0
}

func (s *Server) createCustomerAccount(w http.ResponseWriter, r *http.Request) {
	var input customerDraft
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validCustomerDraft(input) {
		writeError(w, http.StatusBadRequest, "validation_error", "Customer name, phone, or credit limit is invalid.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create customer.", nil)
		return
	}
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO customers (id, name, phone, email, credit_limit_minor)
		VALUES (?, ?, ?, ?, ?)`, id, strings.TrimSpace(input.Name), strings.TrimSpace(input.Phone), strings.TrimSpace(input.Email), input.CreditLimitMinor)
	if err != nil {
		writeDatabaseError(w, err, "Could not create customer.")
		return
	}
	writeJSON(w, http.StatusCreated, customerAccountDTO{
		ID: id, Name: input.Name, Phone: input.Phone, Email: input.Email, CreditLimit: input.CreditLimitMinor, Active: true,
	})
}

func (s *Server) updateCustomerAccount(w http.ResponseWriter, r *http.Request) {
	var input customerDraft
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validCustomerDraft(input) {
		writeError(w, http.StatusBadRequest, "validation_error", "Customer name, phone, or credit limit is invalid.", nil)
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE customers SET name = ?, phone = ?, email = ?, credit_limit_minor = ? WHERE id = ?`,
		strings.TrimSpace(input.Name), strings.TrimSpace(input.Phone), strings.TrimSpace(input.Email), input.CreditLimitMinor, r.PathValue("id"))
	if err != nil {
		writeDatabaseError(w, err, "Could not update customer.")
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "Customer was not found.", nil)
		return
	}
	item, err := s.loadCustomerAccount(r, r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated customer.", nil)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (s *Server) setCustomerAccountActive(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Active bool `json:"active"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE customers SET active = ? WHERE id = ?`, boolInt(input.Active), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not update customer status.", nil)
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "Customer was not found.", nil)
		return
	}
	item, err := s.loadCustomerAccount(r, r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated customer.", nil)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

func (s *Server) loadCustomerAccount(r *http.Request, id string) (customerAccountDTO, error) {
	return scanCustomerAccount(s.db.QueryRowContext(r.Context(), `SELECT id, name, phone, email, credit_limit_minor,
		balance_minor, active, last_purchase_on FROM customers WHERE id = ?`, id))
}

func (s *Server) receiveAccountPayment(w http.ResponseWriter, r *http.Request) {
	var input struct {
		CustomerID  string  `json:"customerId"`
		AmountMinor int64   `json:"amountMinor"`
		Method      string  `json:"method"`
		Reference   *string `json:"reference"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.CustomerID == "" || input.AmountMinor <= 0 ||
		(input.Method != "cash" && input.Method != "card" && input.Method != "mobile") {
		writeError(w, http.StatusBadRequest, "validation_error", "Payment fields are invalid.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not receive payment.", nil)
		return
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(r.Context(), `UPDATE customers SET balance_minor = balance_minor - ? WHERE id = ? AND active = 1 AND balance_minor >= ?`,
		input.AmountMinor, input.CustomerID, input.AmountMinor)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not receive payment.", nil)
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		var balance int64
		err := tx.QueryRowContext(r.Context(), `SELECT balance_minor FROM customers WHERE id = ? AND active = 1`, input.CustomerID).Scan(&balance)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "not_found", "Active customer was not found.", nil)
			return
		}
		writeError(w, http.StatusConflict, "payment_exceeds_balance", "Payment cannot exceed the customer's outstanding balance.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not receive payment.", nil)
		return
	}
	_, err = tx.ExecContext(r.Context(), `INSERT INTO account_payments (id, customer_id, amount_minor, method, reference, received_at)
		VALUES (?, ?, ?, ?, ?, ?)`, id, input.CustomerID, input.AmountMinor, input.Method, input.Reference, time.Now().UTC().Format(time.RFC3339Nano))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record payment.", nil)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not receive payment.", nil)
		return
	}
	item, err := s.loadCustomerAccount(r, input.CustomerID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated customer account.", nil)
		return
	}
	writeJSON(w, http.StatusCreated, item)
}

func (s *Server) listSuppliers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, name, phone FROM suppliers ORDER BY name LIMIT 1000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load suppliers.", nil)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var id, name string
		var phone sql.NullString
		if err := rows.Scan(&id, &name, &phone); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load suppliers.", nil)
			return
		}
		var phoneValue any
		if phone.Valid {
			phoneValue = phone.String
		}
		items = append(items, map[string]any{"id": id, "name": name, "phone": phoneValue})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load suppliers.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

type settingsDTO struct {
	PharmacyName              string `json:"pharmacyName"`
	BranchName                string `json:"branchName"`
	Address                   string `json:"address"`
	Phone                     string `json:"phone"`
	Email                     string `json:"email"`
	TaxPIN                    string `json:"taxPin"`
	LicenseNumber             string `json:"licenceNumber"`
	TaxRateBasisPoints        int    `json:"taxRateBasisPoints"`
	MaxCashierDiscountPercent int    `json:"maxCashierDiscountPercent"`
	AllowCreditSales          bool   `json:"allowCreditSales"`
	PrinterConnection         string `json:"printerConnection"`
	PaperWidth                string `json:"paperWidth"`
	AutoPrintReceipt          bool   `json:"autoPrintReceipt"`
	ReceiptCopies             int    `json:"receiptCopies"`
	PrintPharmacyDetails      bool   `json:"printPharmacyDetails"`
	ReceiptFooter             string `json:"receiptFooter"`
}

func (s *Server) getSettings(w http.ResponseWriter, r *http.Request) {
	var raw string
	err := s.db.QueryRowContext(r.Context(), `SELECT value_json FROM settings WHERE id = 1`).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_configured", "Pharmacy settings have not been configured.", nil)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load settings.", nil)
		return
	}
	writeRawJSON(w, http.StatusOK, []byte(raw))
}

func (s *Server) saveSettings(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin") {
		return
	}
	var input settingsDTO
	if !decodeJSON(w, r, &input) {
		return
	}
	if strings.TrimSpace(input.PharmacyName) == "" || input.TaxRateBasisPoints < 0 ||
		input.MaxCashierDiscountPercent < 0 || input.MaxCashierDiscountPercent > 100 ||
		input.ReceiptCopies < 1 || input.ReceiptCopies > 5 {
		writeError(w, http.StatusBadRequest, "validation_error", "Settings are invalid.", nil)
		return
	}
	raw, err := json.Marshal(input)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not save settings.", nil)
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `INSERT INTO settings (id, value_json) VALUES (1, ?)
		ON CONFLICT(id) DO UPDATE SET value_json = excluded.value_json`, string(raw)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not save settings.", nil)
		return
	}
	writeJSON(w, http.StatusOK, input)
}

type userDTO struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	Email        string  `json:"email"`
	Phone        string  `json:"phone"`
	Role         string  `json:"role"`
	IsActive     bool    `json:"isActive"`
	LastSignInAt *string `json:"lastSignInAt"`
}

func (s *Server) listUsers(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin") {
		return
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, name, email, phone, role, active, last_sign_in_at FROM users ORDER BY name`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load users.", nil)
		return
	}
	defer rows.Close()
	items := make([]userDTO, 0)
	for rows.Next() {
		var item userDTO
		var active int
		if err := rows.Scan(&item.ID, &item.Name, &item.Email, &item.Phone, &item.Role, &active, &item.LastSignInAt); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load users.", nil)
			return
		}
		item.IsActive = active != 0
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load users.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

type userInput struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Phone    string `json:"phone"`
	Role     string `json:"role"`
	Password string `json:"password"`
}

func (s *Server) createUser(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin") {
		return
	}
	var input userInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validUserInput(input, true) {
		writeError(w, http.StatusBadRequest, "validation_error", "User details or password are invalid.", nil)
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create user.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create user.", nil)
		return
	}
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO users (id, name, email, phone, role, password_hash)
		VALUES (?, ?, ?, ?, ?, ?)`, id, strings.TrimSpace(input.Name), strings.ToLower(strings.TrimSpace(input.Email)),
		strings.TrimSpace(input.Phone), input.Role, string(hash))
	if err != nil {
		writeDatabaseError(w, err, "Could not create user.")
		return
	}
	writeJSON(w, http.StatusCreated, userDTO{ID: id, Name: input.Name, Email: input.Email, Phone: input.Phone, Role: input.Role, IsActive: true})
}

func (s *Server) updateUser(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin") {
		return
	}
	var input userInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validUserInput(input, false) {
		writeError(w, http.StatusBadRequest, "validation_error", "User details are invalid.", nil)
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE users SET name = ?, email = ?, phone = ?, role = ? WHERE id = ?`,
		strings.TrimSpace(input.Name), strings.ToLower(strings.TrimSpace(input.Email)), strings.TrimSpace(input.Phone), input.Role, r.PathValue("id"))
	if err != nil {
		writeDatabaseError(w, err, "Could not update user.")
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "User was not found.", nil)
		return
	}
	var item userDTO
	var active int
	err = s.db.QueryRowContext(r.Context(), `SELECT id, name, email, phone, role, active, last_sign_in_at FROM users WHERE id = ?`, r.PathValue("id")).
		Scan(&item.ID, &item.Name, &item.Email, &item.Phone, &item.Role, &active, &item.LastSignInAt)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated user.", nil)
		return
	}
	item.IsActive = active != 0
	writeJSON(w, http.StatusOK, item)
}

func (s *Server) setUserActive(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin") {
		return
	}
	id := r.PathValue("id")
	if id == currentActor(r).ID {
		writeError(w, http.StatusConflict, "cannot_deactivate_self", "You cannot deactivate your own account.", nil)
		return
	}
	var input struct {
		Active bool `json:"active"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if !input.Active {
		var count int
		err := s.db.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM users WHERE role = 'admin' AND active = 1 AND id <> ?`, id).Scan(&count)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not update user status.", nil)
			return
		}
		var role string
		err = s.db.QueryRowContext(r.Context(), `SELECT role FROM users WHERE id = ?`, id).Scan(&role)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, "not_found", "User was not found.", nil)
			return
		}
		if role == "admin" && count == 0 {
			writeError(w, http.StatusConflict, "last_admin", "At least one active administrator must remain.", nil)
			return
		}
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE users SET active = ? WHERE id = ?`, boolInt(input.Active), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not update user status.", nil)
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "User was not found.", nil)
		return
	}
	var item userDTO
	var active int
	err = s.db.QueryRowContext(r.Context(), `SELECT id, name, email, phone, role, active, last_sign_in_at FROM users WHERE id = ?`, id).
		Scan(&item.ID, &item.Name, &item.Email, &item.Phone, &item.Role, &active, &item.LastSignInAt)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated user.", nil)
		return
	}
	item.IsActive = active != 0
	writeJSON(w, http.StatusOK, item)
}

func validUserInput(input userInput, requirePassword bool) bool {
	roles := map[string]bool{"admin": true, "pharmacist": true, "cashier": true}
	return strings.TrimSpace(input.Name) != "" && strings.Contains(input.Email, "@") &&
		roles[input.Role] && (!requirePassword || len(input.Password) >= 12)
}
