package api

import (
	"database/sql"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type productDTO struct {
	ID                   string  `json:"id"`
	SKU                  string  `json:"sku"`
	Barcode              string  `json:"barcode"`
	Name                 string  `json:"name"`
	GenericName          string  `json:"genericName"`
	UnitPriceMinor       int64   `json:"unitPriceMinor"`
	SellableStock        int64   `json:"sellableStock"`
	LowStockThreshold    int64   `json:"lowStockThreshold"`
	RequiresPrescription bool    `json:"requiresPrescription"`
	NearestExpiry        *string `json:"nearestExpiry"`
	NextBatchNumber      *string `json:"nextBatchNumber"`
}

const productSelect = `SELECT m.id, m.sku, m.barcode, m.name, m.generic_name, m.selling_price_minor,
	COALESCE(SUM(CASE WHEN b.quantity_on_hand > 0 AND date(b.expiry_date) >= date('now') THEN b.quantity_on_hand ELSE 0 END), 0),
	m.reorder_level, m.requires_prescription,
	(SELECT MIN(b2.expiry_date) FROM batches b2 WHERE b2.medicine_id = m.id AND b2.quantity_on_hand > 0 AND date(b2.expiry_date) >= date('now')),
	(SELECT b3.batch_number FROM batches b3 WHERE b3.medicine_id = m.id AND b3.quantity_on_hand > 0 AND date(b3.expiry_date) >= date('now') ORDER BY b3.expiry_date, b3.id LIMIT 1)
	FROM medicines m LEFT JOIN batches b ON b.medicine_id = m.id
	WHERE m.active = 1`

func scanProduct(rows scanner) (productDTO, error) {
	var item productDTO
	var rx int
	err := rows.Scan(&item.ID, &item.SKU, &item.Barcode, &item.Name, &item.GenericName, &item.UnitPriceMinor,
		&item.SellableStock, &item.LowStockThreshold, &rx, &item.NearestExpiry, &item.NextBatchNumber)
	item.RequiresPrescription = rx != 0
	return item, err
}

type scanner interface {
	Scan(dest ...any) error
}

func (s *Server) products(w http.ResponseWriter, r *http.Request) {
	query := strings.TrimSpace(r.URL.Query().Get("query"))
	statement := productSelect
	args := []any{}
	if query != "" {
		statement += ` AND (m.name LIKE ? OR m.generic_name LIKE ? OR m.sku LIKE ? OR m.barcode LIKE ?)`
		search := "%" + query + "%"
		args = append(args, search, search, search, search)
	}
	statement += ` GROUP BY m.id ORDER BY m.name LIMIT 500`
	rows, err := s.db.QueryContext(r.Context(), statement, args...)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load products.", nil)
		return
	}
	defer rows.Close()
	items := make([]productDTO, 0)
	for rows.Next() {
		item, err := scanProduct(rows)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load products.", nil)
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load products.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) productByBarcode(w http.ResponseWriter, r *http.Request) {
	barcode, err := url.PathUnescape(r.PathValue("barcode"))
	if err != nil || barcode == "" {
		writeError(w, http.StatusBadRequest, "validation_error", "A valid barcode is required.", nil)
		return
	}
	statement := productSelect + ` AND m.barcode = ? GROUP BY m.id LIMIT 1`
	item, err := scanProduct(s.db.QueryRowContext(r.Context(), statement, barcode))
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "Product was not found.", nil)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load product.", nil)
		return
	}
	writeJSON(w, http.StatusOK, item)
}

type medicineInput struct {
	Name                 string `json:"name"`
	GenericName          string `json:"genericName"`
	DosageForm           string `json:"dosageForm"`
	SKU                  string `json:"sku"`
	Barcode              string `json:"barcode"`
	SellingPriceMinor    int64  `json:"sellingPriceMinor"`
	ReorderLevel         int64  `json:"reorderLevel"`
	RequiresPrescription bool   `json:"requiresPrescription"`
}

type medicineDTO struct {
	ID                   string `json:"id"`
	Name                 string `json:"name"`
	GenericName          string `json:"genericName"`
	DosageForm           string `json:"dosageForm"`
	SKU                  string `json:"sku"`
	Barcode              string `json:"barcode"`
	SellingPriceMinor    int64  `json:"sellingPriceMinor"`
	ReorderLevel         int64  `json:"reorderLevel"`
	RequiresPrescription bool   `json:"requiresPrescription"`
	IsActive             bool   `json:"isActive"`
	StockOnHand          int64  `json:"stockOnHand"`
}

func validateMedicine(input medicineInput) bool {
	validForms := map[string]bool{"tablet": true, "capsule": true, "syrup": true, "injection": true, "cream": true, "drops": true, "inhaler": true, "sachet": true, "other": true}
	return strings.TrimSpace(input.Name) != "" && strings.TrimSpace(input.SKU) != "" &&
		validForms[input.DosageForm] && input.SellingPriceMinor >= 0 && input.ReorderLevel >= 0
}

func (s *Server) listMedicines(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT m.id, m.name, m.generic_name, m.dosage_form, m.sku, m.barcode,
		m.selling_price_minor, m.reorder_level, m.requires_prescription, m.active,
		COALESCE((SELECT SUM(b.quantity_on_hand) FROM batches b WHERE b.medicine_id = m.id), 0)
		FROM medicines m ORDER BY m.name LIMIT 1000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load medicines.", nil)
		return
	}
	defer rows.Close()
	items := make([]medicineDTO, 0)
	for rows.Next() {
		var item medicineDTO
		var rx, active int
		if err := rows.Scan(&item.ID, &item.Name, &item.GenericName, &item.DosageForm, &item.SKU, &item.Barcode,
			&item.SellingPriceMinor, &item.ReorderLevel, &rx, &active, &item.StockOnHand); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load medicines.", nil)
			return
		}
		item.RequiresPrescription, item.IsActive = rx != 0, active != 0
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load medicines.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) createMedicine(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin", "pharmacist") {
		return
	}
	var input medicineInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validateMedicine(input) {
		writeError(w, http.StatusBadRequest, "validation_error", "Medicine fields are invalid.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create medicine.", nil)
		return
	}
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO medicines
		(id, name, generic_name, dosage_form, sku, barcode, selling_price_minor, reorder_level, requires_prescription)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, strings.TrimSpace(input.Name), strings.TrimSpace(input.GenericName), input.DosageForm,
		strings.TrimSpace(input.SKU), strings.TrimSpace(input.Barcode), input.SellingPriceMinor,
		input.ReorderLevel, boolInt(input.RequiresPrescription))
	if err != nil {
		writeDatabaseError(w, err, "Could not create medicine.")
		return
	}
	writeJSON(w, http.StatusCreated, medicineDTO{
		ID: id, Name: input.Name, GenericName: input.GenericName, DosageForm: input.DosageForm, SKU: input.SKU,
		Barcode: input.Barcode, SellingPriceMinor: input.SellingPriceMinor, ReorderLevel: input.ReorderLevel,
		RequiresPrescription: input.RequiresPrescription, IsActive: true,
	})
}

func (s *Server) updateMedicine(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin", "pharmacist") {
		return
	}
	var input medicineInput
	if !decodeJSON(w, r, &input) {
		return
	}
	if !validateMedicine(input) {
		writeError(w, http.StatusBadRequest, "validation_error", "Medicine fields are invalid.", nil)
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE medicines SET name = ?, generic_name = ?, dosage_form = ?,
		sku = ?, barcode = ?, selling_price_minor = ?, reorder_level = ?, requires_prescription = ? WHERE id = ?`,
		strings.TrimSpace(input.Name), strings.TrimSpace(input.GenericName), input.DosageForm, strings.TrimSpace(input.SKU),
		strings.TrimSpace(input.Barcode), input.SellingPriceMinor, input.ReorderLevel, boolInt(input.RequiresPrescription), r.PathValue("id"))
	if err != nil {
		writeDatabaseError(w, err, "Could not update medicine.")
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "Medicine was not found.", nil)
		return
	}
	var active int
	var stock int64
	err = s.db.QueryRowContext(r.Context(), `SELECT active, COALESCE((SELECT SUM(quantity_on_hand) FROM batches WHERE medicine_id = ?), 0) FROM medicines WHERE id = ?`,
		r.PathValue("id"), r.PathValue("id")).Scan(&active, &stock)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load updated medicine.", nil)
		return
	}
	writeJSON(w, http.StatusOK, medicineDTO{
		ID: r.PathValue("id"), Name: input.Name, GenericName: input.GenericName, DosageForm: input.DosageForm,
		SKU: input.SKU, Barcode: input.Barcode, SellingPriceMinor: input.SellingPriceMinor,
		ReorderLevel: input.ReorderLevel, RequiresPrescription: input.RequiresPrescription,
		IsActive: active != 0, StockOnHand: stock,
	})
}

func (s *Server) setMedicineActive(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin", "pharmacist") {
		return
	}
	var input struct {
		Active bool `json:"active"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE medicines SET active = ? WHERE id = ?`, boolInt(input.Active), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not update medicine status.", nil)
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		writeError(w, http.StatusNotFound, "not_found", "Medicine was not found.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": r.PathValue("id"), "active": input.Active})
}

type batchDTO struct {
	ID                string `json:"id"`
	MedicineID        string `json:"medicineId"`
	MedicineName      string `json:"medicineName"`
	BatchNumber       string `json:"batchNumber"`
	SupplierName      string `json:"supplierName"`
	ReceivedOn        string `json:"receivedOn"`
	ExpiryDate        string `json:"expiryDate"`
	QuantityReceived  int64  `json:"quantityReceived"`
	QuantityOnHand    int64  `json:"quantityOnHand"`
	UnitCostMinor     int64  `json:"unitCostMinor"`
	SellingPriceMinor int64  `json:"sellingPriceMinor"`
	ReorderLevel      int64  `json:"reorderLevel"`
}

func (s *Server) listBatches(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT b.id, b.medicine_id, m.name, b.batch_number, b.supplier_name,
		b.received_on, b.expiry_date, b.quantity_received, b.quantity_on_hand, b.unit_cost_minor,
		b.selling_price_minor, m.reorder_level FROM batches b JOIN medicines m ON m.id = b.medicine_id
		ORDER BY b.expiry_date, m.name LIMIT 2000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock batches.", nil)
		return
	}
	defer rows.Close()
	items := make([]batchDTO, 0)
	for rows.Next() {
		var item batchDTO
		if err := rows.Scan(&item.ID, &item.MedicineID, &item.MedicineName, &item.BatchNumber, &item.SupplierName,
			&item.ReceivedOn, &item.ExpiryDate, &item.QuantityReceived, &item.QuantityOnHand, &item.UnitCostMinor,
			&item.SellingPriceMinor, &item.ReorderLevel); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock batches.", nil)
			return
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock batches.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (s *Server) adjustStock(w http.ResponseWriter, r *http.Request) {
	if !s.requireRole(w, r, "admin", "pharmacist") {
		return
	}
	var input struct {
		BatchID          string `json:"batchId"`
		PreviousQuantity int64  `json:"previousQuantity"`
		NewQuantity      int64  `json:"newQuantity"`
		Reason           string `json:"reason"`
		Note             string `json:"note"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	reasons := map[string]bool{"expired": true, "damaged": true, "returnedToSupplier": true, "countCorrection": true, "other": true}
	if input.BatchID == "" || input.PreviousQuantity < 0 || input.NewQuantity < 0 || !reasons[input.Reason] {
		writeError(w, http.StatusBadRequest, "validation_error", "Stock adjustment fields are invalid.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not adjust stock.", nil)
		return
	}
	defer tx.Rollback()
	result, err := tx.ExecContext(r.Context(), `UPDATE batches SET quantity_on_hand = ? WHERE id = ? AND quantity_on_hand = ?`,
		input.NewQuantity, input.BatchID, input.PreviousQuantity)
	if err != nil {
		writeDatabaseError(w, err, "Could not adjust stock.")
		return
	}
	n, _ := result.RowsAffected()
	if n == 0 {
		var exists int
		if err := tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM batches WHERE id = ?`, input.BatchID).Scan(&exists); err != nil || exists == 0 {
			writeError(w, http.StatusNotFound, "not_found", "Stock batch was not found.", nil)
			return
		}
		writeError(w, http.StatusConflict, "stock_changed", "Stock changed since it was loaded; refresh and try again.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not adjust stock.", nil)
		return
	}
	_, err = tx.ExecContext(r.Context(), `INSERT INTO stock_adjustments
		(id, batch_id, previous_quantity, new_quantity, reason, note, adjusted_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		id, input.BatchID, input.PreviousQuantity, input.NewQuantity, input.Reason, strings.TrimSpace(input.Note), time.Now().UTC().Format(time.RFC3339Nano))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not record stock adjustment.", nil)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not adjust stock.", nil)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id, "batchId": input.BatchID, "quantityOnHand": input.NewQuantity})
}

func (s *Server) customers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, name, phone FROM customers WHERE active = 1 ORDER BY name LIMIT 1000`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customers.", nil)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, phone string
		if err := rows.Scan(&id, &name, &phone); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customers.", nil)
			return
		}
		items = append(items, map[string]any{"id": id, "name": name, "phone": phone})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load customers.", nil)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func boolInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func writeDatabaseError(w http.ResponseWriter, err error, message string) {
	if strings.Contains(strings.ToLower(err.Error()), "unique constraint") {
		writeError(w, http.StatusConflict, "already_exists", "A record with these unique fields already exists.", nil)
		return
	}
	writeError(w, http.StatusInternalServerError, "internal_error", message, nil)
}

func parseDate(value string) (time.Time, error) {
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02"} {
		if result, err := time.Parse(layout, value); err == nil {
			return result, nil
		}
	}
	return time.Time{}, errors.New("invalid date")
}

var _ = sql.ErrNoRows
