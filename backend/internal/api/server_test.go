package api

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	_ "modernc.org/sqlite"

	"pharmacy-pos/backend/internal/config"
	"pharmacy-pos/backend/internal/store"
)

func testServer(t *testing.T) (*sql.DB, *httptest.Server) {
	t.Helper()
	db, err := sql.Open("sqlite", fmt.Sprintf("file:%s?mode=memory&cache=shared", t.Name()))
	if err != nil {
		t.Fatal(err)
	}
	db.SetMaxOpenConns(1)
	if err := store.Migrate(db); err != nil {
		t.Fatal(err)
	}
	handler := New(db, config.Config{
		JWTSecret:   []byte("test-secret-with-more-than-thirty-two-characters"),
		CORSOrigins: map[string]struct{}{"http://localhost:3000": {}},
	})
	server := httptest.NewServer(handler)
	t.Cleanup(func() {
		server.Close()
		_ = db.Close()
	})
	return db, server
}

func request(t *testing.T, client *http.Client, method, url, token string, body any) *http.Response {
	t.Helper()
	var content *bytes.Reader
	if body == nil {
		content = bytes.NewReader(nil)
	} else {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		content = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, url, content)
	if err != nil {
		t.Fatal(err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	response, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = response.Body.Close() })
	return response
}

func decodeResponse[T any](t *testing.T, response *http.Response) T {
	t.Helper()
	var value T
	if err := json.NewDecoder(response.Body).Decode(&value); err != nil {
		t.Fatal(err)
	}
	return value
}

func TestBootstrapLoginAndRefreshRotation(t *testing.T) {
	_, server := testServer(t)
	client := server.Client()

	protected := request(t, client, http.MethodGet, server.URL+"/api/v1/medicines", "", nil)
	if protected.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated request status = %d, want 401", protected.StatusCode)
	}
	bootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Admin", "email": "admin@example.test", "phone": "", "password": "a-very-secure-password",
	})
	if bootstrap.StatusCode != http.StatusCreated {
		t.Fatalf("bootstrap status = %d, want 201", bootstrap.StatusCode)
	}
	tokens := decodeResponse[tokenResponse](t, bootstrap)
	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatal("bootstrap did not return both tokens")
	}
	secondBootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Second", "email": "second@example.test", "password": "another-secure-password",
	})
	if secondBootstrap.StatusCode != http.StatusConflict {
		t.Fatalf("second bootstrap status = %d, want 409", secondBootstrap.StatusCode)
	}

	login := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/login", "", map[string]any{
		"email": "ADMIN@example.test", "password": "a-very-secure-password",
	})
	if login.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d, want 200", login.StatusCode)
	}
	loginTokens := decodeResponse[tokenResponse](t, login)
	allowed := request(t, client, http.MethodGet, server.URL+"/api/v1/medicines", loginTokens.AccessToken, nil)
	if allowed.StatusCode != http.StatusOK {
		t.Fatalf("authenticated request status = %d, want 200", allowed.StatusCode)
	}

	refresh := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": loginTokens.RefreshToken,
	})
	if refresh.StatusCode != http.StatusOK {
		t.Fatalf("refresh status = %d, want 200", refresh.StatusCode)
	}
	rotated := decodeResponse[tokenResponse](t, refresh)
	if rotated.RefreshToken == loginTokens.RefreshToken {
		t.Fatal("refresh token was not rotated")
	}
	replayed := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/refresh", "", map[string]string{
		"refreshToken": loginTokens.RefreshToken,
	})
	if replayed.StatusCode != http.StatusUnauthorized {
		t.Fatalf("replayed refresh status = %d, want 401", replayed.StatusCode)
	}
}

func TestSaleIdempotencyAndAtomicStock(t *testing.T) {
	db, server := testServer(t)
	client := server.Client()
	bootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Admin", "email": "admin@example.test", "password": "a-very-secure-password",
	})
	tokens := decodeResponse[tokenResponse](t, bootstrap)
	expiry := time.Now().UTC().AddDate(0, 1, 0).Format("2006-01-02")
	if _, err := db.Exec(`INSERT INTO medicines
		(id, name, generic_name, dosage_form, sku, barcode, selling_price_minor, reorder_level, requires_prescription)
		VALUES ('med-1', 'Test Medicine', '', 'tablet', 'SKU-1', '123456', 1250, 2, 0)`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO batches
		(id, medicine_id, batch_number, supplier_name, received_on, expiry_date, quantity_received, quantity_on_hand, unit_cost_minor, selling_price_minor)
		VALUES ('batch-1', 'med-1', 'B-1', '', date('now'), ?, 5, 5, 600, 1250)`, expiry); err != nil {
		t.Fatal(err)
	}
	body := map[string]any{
		"saleType": "cash", "customerId": nil,
		"lines": []map[string]any{{"productId": "med-1", "quantity": 2, "unitPriceMinor": 1250}},
		"payments": []map[string]any{{"method": "cash", "amountMinor": 2600}},
		"prescriptionVerified": false, "discountMinor": 0, "expectedTotalMinor": 2500,
	}
	postSale := func(total int64) *http.Response {
		body["expectedTotalMinor"] = total
		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/sales", bytes.NewReader(mustJSON(t, body)))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Authorization", "Bearer "+tokens.AccessToken)
		req.Header.Set("Idempotency-Key", "sale-key-1")
		req.Header.Set("Content-Type", "application/json")
		response, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = response.Body.Close() })
		return response
	}

	first := postSale(2499)
	if first.StatusCode != http.StatusConflict {
		t.Fatalf("stale total status = %d, want 409", first.StatusCode)
	}
	var stock int
	if err := db.QueryRow(`SELECT quantity_on_hand FROM batches WHERE id = 'batch-1'`).Scan(&stock); err != nil {
		t.Fatal(err)
	}
	if stock != 5 {
		t.Fatalf("stock after rejected sale = %d, want 5", stock)
	}

	success := postSale(2500)
	if success.StatusCode != http.StatusCreated {
		t.Fatalf("sale status = %d, want 201", success.StatusCode)
	}
	receipt := decodeResponse[saleReceiptDTO](t, success)
	if receipt.TotalMinor != 2500 || receipt.ChangeDueMinor != 100 {
		t.Fatalf("unexpected sale receipt: %+v", receipt)
	}
	retry := postSale(2500)
	if retry.StatusCode != http.StatusOK {
		t.Fatalf("idempotent retry status = %d, want 200", retry.StatusCode)
	}
	retryReceipt := decodeResponse[saleReceiptDTO](t, retry)
	if retryReceipt.ReceiptNumber != receipt.ReceiptNumber {
		t.Fatal("idempotent retry returned a different receipt")
	}
	if err := db.QueryRow(`SELECT quantity_on_hand FROM batches WHERE id = 'batch-1'`).Scan(&stock); err != nil {
		t.Fatal(err)
	}
	if stock != 3 {
		t.Fatalf("stock after sale/retry = %d, want 3", stock)
	}
}

func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	result, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return result
}
