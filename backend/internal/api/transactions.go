package api

import (
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type saleInput struct {
	SaleType             string       `json:"saleType"`
	CustomerID           *string      `json:"customerId"`
	Lines                []saleLineIn `json:"lines"`
	Payments             []paymentIn  `json:"payments"`
	PrescriptionVerified bool         `json:"prescriptionVerified"`
	DiscountMinor        int64        `json:"discountMinor"`
	ExpectedTotalMinor   int64        `json:"expectedTotalMinor"`
}

type saleLineIn struct {
	ProductID      string `json:"productId"`
	Quantity       int64  `json:"quantity"`
	UnitPriceMinor int64  `json:"unitPriceMinor"`
}

type paymentIn struct {
	Method      string  `json:"method"`
	AmountMinor int64   `json:"amountMinor"`
	Reference   *string `json:"reference"`
}

type saleReceiptDTO struct {
	ReceiptNumber        string `json:"receiptNumber"`
	TotalMinor           int64  `json:"totalMinor"`
	ChangeDueMinor       int64  `json:"changeDueMinor"`
	AmountOnAccountMinor int64  `json:"amountOnAccountMinor"`
	CompletedAt          string `json:"completedAt"`
}

func (s *Server) submitSale(w http.ResponseWriter, r *http.Request) {
	var input saleInput
	if !decodeJSON(w, r, &input) {
		return
	}
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" || len(key) > 200 {
		writeError(w, http.StatusBadRequest, "validation_error", "A valid Idempotency-Key header is required.", nil)
		return
	}
	if (input.SaleType != "cash" && input.SaleType != "credit") || len(input.Lines) == 0 || len(input.Lines) > 500 ||
		len(input.Payments) > 100 || input.DiscountMinor < 0 ||
		input.ExpectedTotalMinor < 0 {
		writeError(w, http.StatusBadRequest, "validation_error", "Sale fields are invalid.", nil)
		return
	}
	for _, line := range input.Lines {
		if line.ProductID == "" || line.Quantity <= 0 || line.UnitPriceMinor < 0 {
			writeError(w, http.StatusBadRequest, "validation_error", "Sale line fields are invalid.", nil)
			return
		}
	}
	var paymentTotal, cashTotal int64
	for _, payment := range input.Payments {
		if payment.AmountMinor <= 0 || payment.AmountMinor > 1_000_000_000_000 ||
			(payment.Method != "cash" && payment.Method != "card" && payment.Method != "mobile") ||
			(payment.Method != "cash" && (payment.Reference == nil || strings.TrimSpace(*payment.Reference) == "")) {
			writeError(w, http.StatusBadRequest, "validation_error", "Payment fields are invalid.", nil)
			return
		}
		if paymentTotal > 1_000_000_000_000-payment.AmountMinor {
			writeError(w, http.StatusBadRequest, "validation_error", "Payment total is too large.", nil)
			return
		}
		paymentTotal += payment.AmountMinor
		if payment.Method == "cash" {
			cashTotal += payment.AmountMinor
		}
	}

	bodyHash, err := requestHash(input)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not process sale.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not process sale.", nil)
		return
	}
	defer tx.Rollback()

	var priorHash string
	var priorReceipt saleReceiptDTO
	err = tx.QueryRowContext(r.Context(), `SELECT request_hash, receipt_number, total_minor, change_due_minor,
		amount_on_account_minor, completed_at FROM sales WHERE idempotency_key = ?`, key).
		Scan(&priorHash, &priorReceipt.ReceiptNumber, &priorReceipt.TotalMinor, &priorReceipt.ChangeDueMinor,
			&priorReceipt.AmountOnAccountMinor, &priorReceipt.CompletedAt)
	if err == nil {
		if priorHash != bodyHash {
			writeError(w, http.StatusConflict, "idempotency_conflict", "Idempotency key was already used for a different sale.", nil)
			return
		}
		writeJSON(w, http.StatusOK, priorReceipt)
		return
	}
	if !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not process sale.", nil)
		return
	}
	if input.CustomerID != nil {
		var active int
		if err := tx.QueryRowContext(r.Context(), `SELECT active FROM customers WHERE id = ?`, *input.CustomerID).Scan(&active); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				writeError(w, http.StatusBadRequest, "invalid_customer", "Customer was not found.", nil)
			} else {
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not validate customer.", nil)
			}
			return
		}
		if active != 1 {
			writeError(w, http.StatusConflict, "customer_inactive", "Customer account is inactive.", nil)
			return
		}
	}

	type checkedLine struct {
		id         string
		price      int64
		requiresRx bool
		quantity   int64
	}
	checked := make([]checkedLine, 0, len(input.Lines))
	var subtotal int64
	for _, line := range input.Lines {
		var currentPrice int64
		var requiresRX int
		err := tx.QueryRowContext(r.Context(), `SELECT selling_price_minor, requires_prescription FROM medicines WHERE id = ? AND active = 1`,
			line.ProductID).Scan(&currentPrice, &requiresRX)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusConflict, "product_unavailable", "A product is no longer available.", nil)
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not validate sale products.", nil)
			return
		}
		if currentPrice != line.UnitPriceMinor {
			writeError(w, http.StatusConflict, "price_changed", "A product price changed; refresh the sale.", nil)
			return
		}
		if requiresRX != 0 && !input.PrescriptionVerified {
			writeError(w, http.StatusBadRequest, "prescription_required", "Prescription verification is required.", nil)
			return
		}
		if requiresRX != 0 && currentActor(r).Role == "cashier" {
			writeError(w, http.StatusForbidden, "pharmacist_required", "A pharmacist must authorize prescription medicines.", nil)
			return
		}
		if line.Quantity > 1_000_000 || currentPrice > 1_000_000_000_000/line.Quantity {
			writeError(w, http.StatusBadRequest, "validation_error", "Sale quantities or amounts are too large.", nil)
			return
		}
		lineTotal := currentPrice * line.Quantity
		if subtotal > 1_000_000_000_000-lineTotal {
			writeError(w, http.StatusBadRequest, "validation_error", "Sale total is too large.", nil)
			return
		}
		subtotal += lineTotal
		checked = append(checked, checkedLine{id: line.ProductID, price: currentPrice, requiresRx: requiresRX != 0, quantity: line.Quantity})
	}
	if input.DiscountMinor > subtotal {
		writeError(w, http.StatusBadRequest, "validation_error", "Discount cannot exceed the sale subtotal.", nil)
		return
	}
	if currentActor(r).Role == "cashier" {
		maxDiscount := 0
		var raw string
		if err := tx.QueryRowContext(r.Context(), `SELECT value_json FROM settings WHERE id = 1`).Scan(&raw); err == nil {
			var settings settingsDTO
			if json.Unmarshal([]byte(raw), &settings) == nil {
				maxDiscount = settings.MaxCashierDiscountPercent
			}
		}
		if input.DiscountMinor*100 > subtotal*int64(maxDiscount) {
			writeError(w, http.StatusForbidden, "discount_limit", "Discount exceeds your role limit.", nil)
			return
		}
	}
	taxRate := 0
	var settingsRaw string
	if err := tx.QueryRowContext(r.Context(), `SELECT value_json FROM settings WHERE id = 1`).Scan(&settingsRaw); err == nil {
		var settings settingsDTO
		if json.Unmarshal([]byte(settingsRaw), &settings) == nil {
			taxRate = settings.TaxRateBasisPoints
		}
	}
	taxable := subtotal - input.DiscountMinor
	total := taxable + (taxable*int64(taxRate)+5000)/10000
	if input.ExpectedTotalMinor != total {
		writeError(w, http.StatusConflict, "total_changed", "Sale total changed; refresh and confirm the sale.", map[string]any{"totalMinor": total})
		return
	}

	change := int64(0)
	onAccount := int64(0)
	if input.SaleType == "cash" {
		if paymentTotal < total {
			writeError(w, http.StatusBadRequest, "payment_incomplete", "Payment amount is less than the sale total.", nil)
			return
		}
		change = paymentTotal - total
		if change > cashTotal {
			writeError(w, http.StatusBadRequest, "invalid_change", "Change cannot exceed cash tendered.", nil)
			return
		}
	} else {
		if paymentTotal > total {
			writeError(w, http.StatusBadRequest, "payment_excess", "Credit sale payments cannot exceed the sale total.", nil)
			return
		}
		onAccount = total - paymentTotal
		if onAccount > 0 && input.CustomerID == nil {
			writeError(w, http.StatusBadRequest, "customer_required", "A customer is required for a credit balance.", nil)
			return
		}
		if onAccount > 0 {
			var allowCredit bool
			if err := tx.QueryRowContext(r.Context(), `SELECT json_extract(value_json, '$.allowCreditSales') FROM settings WHERE id = 1`).Scan(&allowCredit); err == nil && !allowCredit {
				writeError(w, http.StatusForbidden, "credit_disabled", "Credit sales are disabled.", nil)
				return
			}
		}
	}

	now := time.Now().UTC()
	date := now.Format(time.RFC3339Nano)
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not process sale.", nil)
		return
	}
	receipt := fmt.Sprintf("%s-%s", now.Format("20060102"), id[:8])
	_, err = tx.ExecContext(r.Context(), `INSERT INTO sales
		(id, receipt_number, idempotency_key, request_hash, customer_id, sale_type, subtotal_minor, discount_minor,
		 total_minor, change_due_minor, amount_on_account_minor, completed_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, receipt, key, bodyHash, input.CustomerID, input.SaleType, subtotal, input.DiscountMinor, total, change, onAccount, date)
	if err != nil {
		writeDatabaseError(w, err, "Could not record sale.")
		return
	}
	for _, line := range checked {
		remaining := line.quantity
		rows, err := tx.QueryContext(r.Context(), `SELECT id, quantity_on_hand, unit_cost_minor FROM batches
			WHERE medicine_id = ? AND quantity_on_hand > 0 AND date(expiry_date) >= date('now')
			ORDER BY expiry_date, id`, line.id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not allocate stock.", nil)
			return
		}
		type allocation struct {
			id             string
			quantity, cost int64
		}
		allocations := make([]allocation, 0)
		for rows.Next() && remaining > 0 {
			var batchID string
			var available, cost int64
			if err := rows.Scan(&batchID, &available, &cost); err != nil {
				_ = rows.Close()
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not allocate stock.", nil)
				return
			}
			quantity := available
			if quantity > remaining {
				quantity = remaining
			}
			allocations = append(allocations, allocation{id: batchID, quantity: quantity, cost: cost})
			remaining -= quantity
		}
		err = rows.Err()
		_ = rows.Close()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not allocate stock.", nil)
			return
		}
		if remaining != 0 {
			writeError(w, http.StatusConflict, "insufficient_stock", "Available stock changed; refresh the sale.", nil)
			return
		}
		for _, allocation := range allocations {
			lineID, err := randomID()
			if err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not record sale lines.", nil)
				return
			}
			result, err := tx.ExecContext(r.Context(), `UPDATE batches SET quantity_on_hand = quantity_on_hand - ?
				WHERE id = ? AND quantity_on_hand >= ?`, allocation.quantity, allocation.id, allocation.quantity)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not update stock.", nil)
				return
			}
			updated, _ := result.RowsAffected()
			if updated != 1 {
				writeError(w, http.StatusConflict, "insufficient_stock", "Available stock changed; refresh the sale.", nil)
				return
			}
			if _, err := tx.ExecContext(r.Context(), `INSERT INTO sale_lines
				(id, sale_id, medicine_id, batch_id, quantity, unit_price_minor, unit_cost_minor) VALUES (?, ?, ?, ?, ?, ?, ?)`,
				lineID, id, line.id, allocation.id, allocation.quantity, line.price, allocation.cost); err != nil {
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not record sale lines.", nil)
				return
			}
		}
	}
	remainingChange := change
	for _, payment := range input.Payments {
		amount := payment.AmountMinor
		if payment.Method == "cash" && remainingChange > 0 {
			deduction := amount
			if deduction > remainingChange {
				deduction = remainingChange
			}
			amount -= deduction
			remainingChange -= deduction
		}
		if amount == 0 {
			continue
		}
		paymentID, err := randomID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not record payments.", nil)
			return
		}
		if _, err := tx.ExecContext(r.Context(), `INSERT INTO sale_payments (id, sale_id, method, amount_minor) VALUES (?, ?, ?, ?)`,
			paymentID, id, payment.Method, amount); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not record payments.", nil)
			return
		}
	}
	if onAccount > 0 {
		result, err := tx.ExecContext(r.Context(), `UPDATE customers SET balance_minor = balance_minor + ?, last_purchase_on = ?
			WHERE id = ? AND active = 1 AND balance_minor + ? <= credit_limit_minor`,
			onAccount, now.Format("2006-01-02"), *input.CustomerID, onAccount)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not update customer balance.", nil)
			return
		}
		updated, _ := result.RowsAffected()
		if updated == 0 {
			writeError(w, http.StatusConflict, "credit_limit", "Customer account is inactive or credit limit would be exceeded.", nil)
			return
		}
	}
	if input.CustomerID != nil && onAccount == 0 {
		if _, err := tx.ExecContext(r.Context(), `UPDATE customers SET last_purchase_on = ? WHERE id = ?`,
			now.Format("2006-01-02"), *input.CustomerID); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not update customer purchase date.", nil)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not process sale.", nil)
		return
	}
	writeJSON(w, http.StatusCreated, saleReceiptDTO{
		ReceiptNumber: receipt, TotalMinor: total, ChangeDueMinor: change,
		AmountOnAccountMinor: onAccount, CompletedAt: date,
	})
}

func requestHash(value any) (string, error) {
	raw, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	hash := sha256.Sum256(raw)
	return fmt.Sprintf("%x", hash[:]), nil
}

type purchaseInput struct {
	SupplierID    *string          `json:"supplierId"`
	InvoiceNumber string           `json:"invoiceNumber"`
	ReceivedOn    string           `json:"receivedOn"`
	PaymentStatus string           `json:"paymentStatus"`
	Lines         []purchaseLineIn `json:"lines"`
}

type purchaseLineIn struct {
	ProductID         string  `json:"productId"`
	ProductName       string  `json:"productName"`
	BatchNumber       string  `json:"batchNumber"`
	ExpiryDate        *string `json:"expiryDate"`
	Quantity          int64   `json:"quantity"`
	UnitCostMinor     int64   `json:"unitCostMinor"`
	SellingPriceMinor int64   `json:"sellingPriceMinor"`
}

type purchaseDTO struct {
	ID            string `json:"id"`
	Reference     string `json:"reference"`
	SupplierName  string `json:"supplierName"`
	InvoiceNumber string `json:"invoiceNumber"`
	ReceivedOn    string `json:"receivedOn"`
	PaymentStatus string `json:"paymentStatus"`
	LineCount     int64  `json:"lineCount"`
	UnitCount     int64  `json:"unitCount"`
	TotalMinor    int64  `json:"totalMinor"`
}

func (s *Server) recordPurchase(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin", "pharmacist") {
		return
	}
	var input purchaseInput
	if !decodeJSON(w, r, &input) {
		return
	}
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" || len(key) > 200 || strings.TrimSpace(input.InvoiceNumber) == "" ||
		(input.PaymentStatus != "paid" && input.PaymentStatus != "onCredit") ||
		len(input.Lines) == 0 || len(input.Lines) > 500 {
		writeError(w, http.StatusBadRequest, "validation_error", "Purchase fields and Idempotency-Key are required.", nil)
		return
	}
	received, err := parseDate(input.ReceivedOn)
	if err != nil {
		writeError(w, http.StatusBadRequest, "validation_error", "receivedOn must be an ISO-8601 date.", nil)
		return
	}
	for _, line := range input.Lines {
		if line.ProductID == "" || strings.TrimSpace(line.BatchNumber) == "" || line.Quantity <= 0 ||
			line.UnitCostMinor < 0 || line.SellingPriceMinor < 0 {
			writeError(w, http.StatusBadRequest, "validation_error", "Purchase line fields are invalid.", nil)
			return
		}
		if line.ExpiryDate != nil {
			expiry, err := parseDate(*line.ExpiryDate)
			if err != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "expiryDate must be an ISO-8601 date.", nil)
				return
			}
			if !expiry.After(received) {
				writeError(w, http.StatusBadRequest, "validation_error", "expiryDate must be after receivedOn.", nil)
				return
			}
		}
	}
	bodyHash, err := requestHash(input)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase.", nil)
		return
	}
	defer tx.Rollback()
	var priorHash string
	var prior purchaseDTO
	err = tx.QueryRowContext(r.Context(), `SELECT p.request_hash, p.id, p.reference, COALESCE(s.name, ''), p.invoice_number,
		p.received_on, p.payment_status, COUNT(pl.id), COALESCE(SUM(pl.quantity), 0), p.total_minor
		FROM purchases p LEFT JOIN suppliers s ON s.id = p.supplier_id LEFT JOIN purchase_lines pl ON pl.purchase_id = p.id
		WHERE p.idempotency_key = ? GROUP BY p.id`, key).
		Scan(&priorHash, &prior.ID, &prior.Reference, &prior.SupplierName, &prior.InvoiceNumber, &prior.ReceivedOn,
			&prior.PaymentStatus, &prior.LineCount, &prior.UnitCount, &prior.TotalMinor)
	if err == nil {
		if priorHash != bodyHash {
			writeError(w, http.StatusConflict, "idempotency_conflict", "Idempotency key was already used for a different purchase.", nil)
			return
		}
		writeJSON(w, http.StatusOK, prior)
		return
	}
	if !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase.", nil)
		return
	}
	supplierName := ""
	if input.SupplierID != nil {
		if err := tx.QueryRowContext(r.Context(), `SELECT name FROM suppliers WHERE id = ?`, *input.SupplierID).Scan(&supplierName); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				writeError(w, http.StatusBadRequest, "invalid_supplier", "Supplier was not found.", nil)
			} else {
				writeError(w, http.StatusInternalServerError, "internal_error", "Could not validate supplier.", nil)
			}
			return
		}
	}
	var total, units int64
	for _, line := range input.Lines {
		if line.Quantity > 1_000_000 || line.UnitCostMinor > 1_000_000_000_000/line.Quantity {
			writeError(w, http.StatusBadRequest, "validation_error", "Purchase quantities or amount are too large.", nil)
			return
		}
		lineTotal := line.Quantity * line.UnitCostMinor
		if total > 1_000_000_000_000-lineTotal {
			writeError(w, http.StatusBadRequest, "validation_error", "Purchase total is too large.", nil)
			return
		}
		total += lineTotal
		units += line.Quantity
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase.", nil)
		return
	}
	reference := "PUR-" + strings.ToUpper(id[:8])
	_, err = tx.ExecContext(r.Context(), `INSERT INTO purchases
		(id, reference, idempotency_key, request_hash, supplier_id, invoice_number, received_on, payment_status, total_minor)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, reference, key, bodyHash, input.SupplierID, strings.TrimSpace(input.InvoiceNumber),
		received.Format("2006-01-02"), input.PaymentStatus, total)
	if err != nil {
		writeDatabaseError(w, err, "Could not record purchase.")
		return
	}
	for _, line := range input.Lines {
		var medicineExists int
		if err := tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM medicines WHERE id = ?`, line.ProductID).Scan(&medicineExists); err != nil || medicineExists == 0 {
			writeError(w, http.StatusBadRequest, "invalid_product", "Purchase contains an unknown medicine.", nil)
			return
		}
		batchID, err := randomID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase lines.", nil)
			return
		}
		expiry := ""
		if line.ExpiryDate != nil {
			expiryDate, parseErr := parseDate(*line.ExpiryDate)
			if parseErr != nil {
				writeError(w, http.StatusBadRequest, "validation_error", "expiryDate must be an ISO-8601 date.", nil)
				return
			}
			expiry = expiryDate.Format("2006-01-02")
		} else {
			expiry = "9999-12-31"
		}
		_, err = tx.ExecContext(r.Context(), `INSERT INTO batches
			(id, medicine_id, batch_number, supplier_name, received_on, expiry_date, quantity_received, quantity_on_hand,
			 unit_cost_minor, selling_price_minor) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			batchID, line.ProductID, strings.TrimSpace(line.BatchNumber), supplierName, received.Format("2006-01-02"),
			expiry, line.Quantity, line.Quantity, line.UnitCostMinor, line.SellingPriceMinor)
		if err != nil {
			writeDatabaseError(w, err, "Could not create stock batch.")
			return
		}
		if _, err := tx.ExecContext(r.Context(), `UPDATE medicines SET selling_price_minor = ? WHERE id = ?`,
			line.SellingPriceMinor, line.ProductID); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not update medicine price.", nil)
			return
		}
		purchaseLineID, err := randomID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase lines.", nil)
			return
		}
		if _, err := tx.ExecContext(r.Context(), `INSERT INTO purchase_lines
			(id, purchase_id, medicine_id, batch_id, quantity, unit_cost_minor) VALUES (?, ?, ?, ?, ?, ?)`,
			purchaseLineID, id, line.ProductID, batchID, line.Quantity, line.UnitCostMinor); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase lines.", nil)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record purchase.", nil)
		return
	}
	writeJSON(w, http.StatusCreated, purchaseDTO{
		ID: id, Reference: reference, SupplierName: supplierName, InvoiceNumber: input.InvoiceNumber,
		ReceivedOn: received.Format("2006-01-02"), PaymentStatus: input.PaymentStatus,
		LineCount: int64(len(input.Lines)), UnitCount: units, TotalMinor: total,
	})
}

func (s *Server) listPurchases(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT p.id, p.reference, COALESCE(s.name, ''), p.invoice_number,
		p.received_on, p.payment_status, COUNT(pl.id), COALESCE(SUM(pl.quantity), 0), p.total_minor
		FROM purchases p LEFT JOIN suppliers s ON s.id = p.supplier_id
		LEFT JOIN purchase_lines pl ON pl.purchase_id = p.id GROUP BY p.id ORDER BY p.received_on DESC LIMIT 1000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load purchases.", nil)
		return
	}
	defer rows.Close()
	items := make([]purchaseDTO, 0)
	for rows.Next() {
		var item purchaseDTO
		if err := rows.Scan(&item.ID, &item.Reference, &item.SupplierName, &item.InvoiceNumber, &item.ReceivedOn,
			&item.PaymentStatus, &item.LineCount, &item.UnitCount, &item.TotalMinor); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load purchases.", nil)
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load purchases.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}
