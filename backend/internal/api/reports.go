package api

import (
	"database/sql"
	"errors"
	"net/http"
	"time"
)

func reportRange(r *http.Request) (time.Time, time.Time, bool) {
	from, errFrom := parseDate(r.URL.Query().Get("from"))
	to, errTo := parseDate(r.URL.Query().Get("to"))
	if errFrom != nil || errTo != nil || from.After(to) || to.Sub(from) > 366*10*24*time.Hour {
		return time.Time{}, time.Time{}, false
	}
	return from, to, true
}

func (s *Server) salesReport(w http.ResponseWriter, r *http.Request) {
	from, to, ok := reportRange(r)
	if !ok {
		writeError(w, http.StatusBadRequest, "validation_error", "from and to must be valid ISO-8601 dates in ascending order.", nil)
		return
	}
	days := make([]map[string]any, 0)
	for date := from; !date.After(to); date = date.AddDate(0, 0, 1) {
		var transactions, items int64
		var gross, discount int64
		err := s.db.QueryRowContext(r.Context(), `SELECT COUNT(*), COALESCE(SUM(s.item_count), 0),
			COALESCE(SUM(s.subtotal_minor), 0), COALESCE(SUM(s.discount_minor), 0)
			FROM (SELECT s.id, s.subtotal_minor, s.discount_minor, date(s.completed_at) AS sale_date,
				(SELECT COALESCE(SUM(quantity), 0) FROM sale_lines sl WHERE sl.sale_id = s.id) AS item_count
				FROM sales s) s WHERE s.sale_date = ?`,
			date.Format("2006-01-02")).Scan(&transactions, &items, &gross, &discount)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load sales report.", nil)
			return
		}
		days = append(days, map[string]any{
			"date": date.Format("2006-01-02"), "transactions": transactions, "itemsSold": items,
			"grossMinor": gross, "discountMinor": discount,
		})
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT method, SUM(amount_minor) FROM sale_payments sp
		JOIN sales s ON s.id = sp.sale_id WHERE date(s.completed_at) BETWEEN ? AND ? GROUP BY method`,
		from.Format("2006-01-02"), to.Format("2006-01-02"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load payment totals.", nil)
		return
	}
	defer rows.Close()
	payments := make([]map[string]any, 0)
	for rows.Next() {
		var method string
		var amount int64
		if err := rows.Scan(&method, &amount); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load payment totals.", nil)
			return
		}
		payments = append(payments, map[string]any{"method": method, "amountMinor": amount})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load payment totals.", nil)
		return
	}
	var credit int64
	if err := s.db.QueryRowContext(r.Context(), `SELECT COALESCE(SUM(amount_on_account_minor), 0) FROM sales
		WHERE date(completed_at) BETWEEN ? AND ?`, from.Format("2006-01-02"), to.Format("2006-01-02")).Scan(&credit); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load payment totals.", nil)
		return
	}
	payments = append(payments, map[string]any{"method": "credit", "amountMinor": credit})
	writeJSON(w, http.StatusOK, map[string]any{
		"range": map[string]string{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"days":  days, "byPayment": payments,
	})
}

func (s *Server) profitReport(w http.ResponseWriter, r *http.Request) {
	from, to, ok := reportRange(r)
	if !ok {
		writeError(w, http.StatusBadRequest, "validation_error", "from and to must be valid ISO-8601 dates in ascending order.", nil)
		return
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT m.name, SUM(sl.quantity),
		SUM(sl.quantity * sl.unit_price_minor), SUM(sl.quantity * sl.unit_cost_minor)
		FROM sale_lines sl JOIN sales s ON s.id = sl.sale_id JOIN medicines m ON m.id = sl.medicine_id
		WHERE date(s.completed_at) BETWEEN ? AND ? GROUP BY sl.medicine_id ORDER BY m.name`,
		from.Format("2006-01-02"), to.Format("2006-01-02"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load profit report.", nil)
		return
	}
	defer rows.Close()
	products := make([]map[string]any, 0)
	for rows.Next() {
		var name string
		var units, revenue, cost int64
		if err := rows.Scan(&name, &units, &revenue, &cost); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load profit report.", nil)
			return
		}
		products = append(products, map[string]any{
			"name": name, "unitsSold": units, "revenueMinor": revenue, "costMinor": cost,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load profit report.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"range":    map[string]string{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"products": products,
	})
}

func (s *Server) lossesReport(w http.ResponseWriter, r *http.Request) {
	from, to, ok := reportRange(r)
	if !ok {
		writeError(w, http.StatusBadRequest, "validation_error", "from and to must be valid ISO-8601 dates in ascending order.", nil)
		return
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT a.adjusted_at, m.name, b.batch_number,
		ABS(a.previous_quantity - a.new_quantity), b.unit_cost_minor, a.reason
		FROM stock_adjustments a JOIN batches b ON b.id = a.batch_id JOIN medicines m ON m.id = b.medicine_id
		WHERE date(a.adjusted_at) BETWEEN ? AND ? AND a.new_quantity < a.previous_quantity
		ORDER BY a.adjusted_at DESC`,
		from.Format("2006-01-02"), to.Format("2006-01-02"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load losses report.", nil)
		return
	}
	defer rows.Close()
	items := make([]map[string]any, 0)
	for rows.Next() {
		var date, name, batch, reason string
		var quantity, unitCost int64
		if err := rows.Scan(&date, &name, &batch, &quantity, &unitCost, &reason); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load losses report.", nil)
			return
		}
		switch reason {
		case "returnedToSupplier":
			reason = "damaged"
		case "countCorrection":
			reason = "countShortage"
		}
		if reason != "expired" && reason != "damaged" && reason != "countShortage" {
			reason = "countShortage"
		}
		items = append(items, map[string]any{
			"date": date, "medicineName": name, "batchNumber": batch, "quantity": quantity,
			"unitCostMinor": unitCost, "reason": reason,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load losses report.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"range": map[string]string{"from": from.Format("2006-01-02"), "to": to.Format("2006-01-02")},
		"rows":  items,
	})
}

func (s *Server) dashboard(w http.ResponseWriter, r *http.Request) {
	today := time.Now().UTC().Format("2006-01-02")
	var total, transactions, items, credit int64
	err := s.db.QueryRowContext(r.Context(), `SELECT COALESCE(SUM(total_minor), 0), COUNT(*),
		COALESCE((SELECT SUM(quantity) FROM sale_lines sl JOIN sales s2 ON s2.id = sl.sale_id WHERE date(s2.completed_at) = ?), 0),
		COALESCE((SELECT SUM(balance_minor) FROM customers), 0) FROM sales WHERE date(completed_at) = ?`, today, today).
		Scan(&total, &transactions, &items, &credit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load dashboard.", nil)
		return
	}
	weekly := make([]map[string]any, 0, 7)
	for offset := 6; offset >= 0; offset-- {
		date := time.Now().UTC().AddDate(0, 0, -offset).Format("2006-01-02")
		var dayTotal int64
		if err := s.db.QueryRowContext(r.Context(), `SELECT COALESCE(SUM(total_minor), 0) FROM sales WHERE date(completed_at) = ?`, date).Scan(&dayTotal); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load dashboard.", nil)
			return
		}
		weekly = append(weekly, map[string]any{"date": date, "totalMinor": dayTotal})
	}
	lowStock := make([]map[string]any, 0)
	rows, err := s.db.QueryContext(r.Context(), `SELECT m.name,
		COALESCE(SUM(CASE WHEN b.quantity_on_hand > 0 AND date(b.expiry_date) >= date('now') THEN b.quantity_on_hand ELSE 0 END), 0),
		m.reorder_level FROM medicines m LEFT JOIN batches b ON b.medicine_id = m.id WHERE m.active = 1
		GROUP BY m.id HAVING COALESCE(SUM(CASE WHEN b.quantity_on_hand > 0 AND date(b.expiry_date) >= date('now') THEN b.quantity_on_hand ELSE 0 END), 0) <= m.reorder_level
		ORDER BY m.name LIMIT 100`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock alerts.", nil)
		return
	}
	for rows.Next() {
		var name string
		var stock, threshold int64
		if err := rows.Scan(&name, &stock, &threshold); err != nil {
			_ = rows.Close()
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock alerts.", nil)
			return
		}
		lowStock = append(lowStock, map[string]any{"productName": name, "sellableStock": stock, "lowStockThreshold": threshold})
	}
	if err := rows.Err(); err != nil {
		_ = rows.Close()
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load stock alerts.", nil)
		return
	}
	_ = rows.Close()

	expiring := make([]map[string]any, 0)
	rows, err = s.db.QueryContext(r.Context(), `SELECT m.name, b.batch_number, b.expiry_date, b.quantity_on_hand
		FROM batches b JOIN medicines m ON m.id = b.medicine_id WHERE b.quantity_on_hand > 0
		AND date(b.expiry_date) <= date('now', '+90 days') ORDER BY b.expiry_date LIMIT 200`)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load expiry alerts.", nil)
		return
	}
	for rows.Next() {
		var name, batch, expiry string
		var quantity int64
		if err := rows.Scan(&name, &batch, &expiry, &quantity); err != nil {
			_ = rows.Close()
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load expiry alerts.", nil)
			return
		}
		expiring = append(expiring, map[string]any{"productName": name, "batchNumber": batch, "expiryDate": expiry, "quantity": quantity})
	}
	if err := rows.Err(); err != nil {
		_ = rows.Close()
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load expiry alerts.", nil)
		return
	}
	_ = rows.Close()

	topProducts := make([]map[string]any, 0)
	rows, err = s.db.QueryContext(r.Context(), `SELECT m.name, SUM(sl.quantity), SUM(sl.quantity * sl.unit_price_minor)
		FROM sale_lines sl JOIN sales s ON s.id = sl.sale_id JOIN medicines m ON m.id = sl.medicine_id
		WHERE date(s.completed_at) = ? GROUP BY sl.medicine_id ORDER BY SUM(sl.quantity) DESC LIMIT 5`, today)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load top products.", nil)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var name string
		var quantity, revenue int64
		if err := rows.Scan(&name, &quantity, &revenue); err != nil {
			writeError(w, http.StatusInternalServerError, "internal_error", "Could not load top products.", nil)
			return
		}
		topProducts = append(topProducts, map[string]any{"name": name, "unitsSold": quantity, "revenueMinor": revenue})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not load top products.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"todaySalesMinor": total, "todayTransactions": transactions, "todayItemsSold": items,
		"creditOutstandingMinor": credit, "weeklySales": weekly, "lowStock": lowStock,
		"expiring": expiring, "topProducts": topProducts,
	})
}

func ignoreNoRows(err error) bool {
	return errors.Is(err, sql.ErrNoRows)
}
