package api

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
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
		JWTSecret:      []byte("test-secret-with-more-than-thirty-two-characters"),
		BootstrapToken: "test-bootstrap-token-with-more-than-thirty-two",
		CORSOrigins:    map[string]struct{}{"http://localhost:3000": {}},
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
	if strings.HasSuffix(url, "/api/v1/auth/bootstrap") {
		req.Header.Set("X-Bootstrap-Token", "test-bootstrap-token-with-more-than-thirty-two")
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

	unprotectedBootstrap, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/auth/bootstrap",
		bytes.NewReader(mustJSON(t, map[string]string{
			"name": "Attacker", "email": "attacker@example.test", "password": "a-very-secure-password",
		})))
	if err != nil {
		t.Fatal(err)
	}
	unprotectedBootstrap.Header.Set("Content-Type", "application/json")
	unprotectedResponse, err := client.Do(unprotectedBootstrap)
	if err != nil {
		t.Fatal(err)
	}
	_ = unprotectedResponse.Body.Close()
	if unprotectedResponse.StatusCode != http.StatusForbidden {
		t.Fatalf("bootstrap without secret status = %d, want 403", unprotectedResponse.StatusCode)
	}

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

func TestUserInvitationCanBeAcceptedOnlyOnce(t *testing.T) {
	_, server := testServer(t)
	client := server.Client()
	bootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Admin", "email": "admin@example.test", "password": "a-very-secure-password",
	})
	tokens := decodeResponse[tokenResponse](t, bootstrap)
	create := request(t, client, http.MethodPost, server.URL+"/api/v1/users", tokens.AccessToken, map[string]any{
		"name": "Cashier", "email": "cashier@example.test", "phone": "", "role": "cashier",
	})
	if create.StatusCode != http.StatusCreated {
		t.Fatalf("create user status = %d, want 201", create.StatusCode)
	}
	var response map[string]any
	if err := json.NewDecoder(create.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	invitation, ok := response["invitationToken"].(string)
	if !ok || invitation == "" {
		t.Fatal("create user did not return an invitation token")
	}
	invalidLogin := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/login", "", map[string]string{
		"email": "cashier@example.test", "password": invitation,
	})
	if invalidLogin.StatusCode != http.StatusUnauthorized {
		t.Fatalf("login with invitation token status = %d, want 401", invalidLogin.StatusCode)
	}
	accept := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/accept-invitation", "", map[string]string{
		"token": invitation, "password": "another-secure-password",
	})
	if accept.StatusCode != http.StatusNoContent {
		t.Fatalf("accept invitation status = %d, want 204", accept.StatusCode)
	}
	replay := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/accept-invitation", "", map[string]string{
		"token": invitation, "password": "yet-another-secure-password",
	})
	if replay.StatusCode != http.StatusUnauthorized {
		t.Fatalf("replayed invitation status = %d, want 401", replay.StatusCode)
	}
	login := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/login", "", map[string]string{
		"email": "cashier@example.test", "password": "another-secure-password",
	})
	if login.StatusCode != http.StatusOK {
		t.Fatalf("invited user login status = %d, want 200", login.StatusCode)
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
		"lines":                []map[string]any{{"productId": "med-1", "quantity": 2, "unitPriceMinor": 1250}},
		"payments":             []map[string]any{{"method": "cash", "amountMinor": 2600}},
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

	date := time.Now().UTC().Format("2006-01-02")
	report := request(t, client, http.MethodGet,
		server.URL+"/api/v1/reports/sales?from="+date+"&to="+date, tokens.AccessToken, nil)
	if report.StatusCode != http.StatusOK {
		t.Fatalf("sales report status = %d, want 200", report.StatusCode)
	}
	var reportData struct {
		Days []struct {
			Transactions  int64 `json:"transactions"`
			ItemsSold     int64 `json:"itemsSold"`
			GrossMinor    int64 `json:"grossMinor"`
			DiscountMinor int64 `json:"discountMinor"`
		} `json:"days"`
		ByPayment []struct {
			Method      string `json:"method"`
			AmountMinor int64  `json:"amountMinor"`
		} `json:"byPayment"`
	}
	if err := json.NewDecoder(report.Body).Decode(&reportData); err != nil {
		t.Fatal(err)
	}
	if len(reportData.Days) != 1 || reportData.Days[0].Transactions != 1 ||
		reportData.Days[0].ItemsSold != 2 || reportData.Days[0].GrossMinor != 2500 {
		t.Fatalf("unexpected sales report: %+v", reportData)
	}
	var paymentTotal int64
	for _, payment := range reportData.ByPayment {
		paymentTotal += payment.AmountMinor
	}
	if paymentTotal != reportData.Days[0].GrossMinor {
		t.Fatalf("payment totals = %d, gross sales = %d", paymentTotal, reportData.Days[0].GrossMinor)
	}
}

func TestHealthAndCorsAllowlist(t *testing.T) {
	_, server := testServer(t)
	client := server.Client()
	health := request(t, client, http.MethodGet, server.URL+"/health", "", nil)
	if health.StatusCode != http.StatusOK {
		t.Fatalf("health status = %d, want 200", health.StatusCode)
	}
	req, err := http.NewRequest(http.MethodGet, server.URL+"/health", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Origin", "https://not-allowed.example")
	response, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusForbidden {
		t.Fatalf("disallowed origin status = %d, want 403", response.StatusCode)
	}
}

func TestSettingsAreSeededAndTaxRateIsBounded(t *testing.T) {
	_, server := testServer(t)
	client := server.Client()
	bootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Admin", "email": "admin@example.test", "password": "a-very-secure-password",
	})
	tokens := decodeResponse[tokenResponse](t, bootstrap)
	settings := request(t, client, http.MethodGet, server.URL+"/api/v1/settings", tokens.AccessToken, nil)
	if settings.StatusCode != http.StatusOK {
		t.Fatalf("initial settings status = %d, want 200", settings.StatusCode)
	}
	var initial map[string]any
	if err := json.NewDecoder(settings.Body).Decode(&initial); err != nil {
		t.Fatal(err)
	}
	if initial["allowCreditSales"] != true {
		t.Fatalf("default allowCreditSales = %v, want true", initial["allowCreditSales"])
	}

	initial["pharmacyName"] = "Example Pharmacy"
	initial["taxRateBasisPoints"] = 10001
	save := request(t, client, http.MethodPut, server.URL+"/api/v1/settings", tokens.AccessToken, initial)
	if save.StatusCode != http.StatusBadRequest {
		t.Fatalf("invalid tax settings status = %d, want 400", save.StatusCode)
	}
}

func TestPurchaseStockAndCustomerPaymentEndpoints(t *testing.T) {
	db, server := testServer(t)
	client := server.Client()
	bootstrap := request(t, client, http.MethodPost, server.URL+"/api/v1/auth/bootstrap", "", map[string]any{
		"name": "Admin", "email": "admin@example.test", "password": "a-very-secure-password",
	})
	tokens := decodeResponse[tokenResponse](t, bootstrap)

	medicineResponse := request(t, client, http.MethodPost, server.URL+"/api/v1/medicines", tokens.AccessToken, map[string]any{
		"name": "Test Medicine", "genericName": "Test", "dosageForm": "tablet", "sku": "MED-001",
		"barcode": "111222", "sellingPriceMinor": 1000, "reorderLevel": 3, "requiresPrescription": false,
	})
	if medicineResponse.StatusCode != http.StatusCreated {
		t.Fatalf("create medicine status = %d, want 201", medicineResponse.StatusCode)
	}
	medicine := decodeResponse[medicineDTO](t, medicineResponse)

	supplierResponse := request(t, client, http.MethodPost, server.URL+"/api/v1/suppliers", tokens.AccessToken, map[string]any{
		"name": "Test Supplier", "phone": "+254700000000",
	})
	if supplierResponse.StatusCode != http.StatusCreated {
		t.Fatalf("create supplier status = %d, want 201", supplierResponse.StatusCode)
	}
	var supplier struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(supplierResponse.Body).Decode(&supplier); err != nil {
		t.Fatal(err)
	}

	received := time.Now().UTC().Format("2006-01-02")
	expiry := time.Now().UTC().AddDate(1, 0, 0).Format("2006-01-02")
	purchaseBody := map[string]any{
		"supplierId": supplier.ID, "invoiceNumber": "INV-001", "receivedOn": received, "paymentStatus": "paid",
		"lines": []map[string]any{{
			"productId": medicine.ID, "productName": medicine.Name, "batchNumber": "LOT-1",
			"expiryDate": expiry, "quantity": 5, "unitCostMinor": 500, "sellingPriceMinor": 1000,
		}},
	}
	purchaseRequest := func() *http.Response {
		req, err := http.NewRequest(http.MethodPost, server.URL+"/api/v1/purchases", bytes.NewReader(mustJSON(t, purchaseBody)))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Authorization", "Bearer "+tokens.AccessToken)
		req.Header.Set("Idempotency-Key", "purchase-key-1")
		req.Header.Set("Content-Type", "application/json")
		response, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = response.Body.Close() })
		return response
	}
	purchase := purchaseRequest()
	if purchase.StatusCode != http.StatusCreated {
		t.Fatalf("record purchase status = %d", purchase.StatusCode)
	}
	purchaseResult := decodeResponse[purchaseDTO](t, purchase)
	if purchaseResult.TotalMinor != 2500 || purchaseResult.UnitCount != 5 {
		t.Fatalf("unexpected purchase result: %+v", purchaseResult)
	}
	retry := purchaseRequest()
	if retry.StatusCode != http.StatusOK {
		t.Fatalf("idempotent purchase retry status = %d, want 200", retry.StatusCode)
	}

	batchesResponse := request(t, client, http.MethodGet, server.URL+"/api/v1/stock/batches", tokens.AccessToken, nil)
	if batchesResponse.StatusCode != http.StatusOK {
		t.Fatalf("list batches status = %d", batchesResponse.StatusCode)
	}
	batches := decodeResponse[[]batchDTO](t, batchesResponse)
	if len(batches) != 1 || batches[0].QuantityOnHand != 5 {
		t.Fatalf("unexpected stock batches: %+v", batches)
	}
	adjusted := request(t, client, http.MethodPost, server.URL+"/api/v1/stock/adjustments", tokens.AccessToken, map[string]any{
		"batchId": batches[0].ID, "previousQuantity": 5, "newQuantity": 4,
		"reason": "countCorrection", "note": "",
	})
	if adjusted.StatusCode != http.StatusCreated {
		t.Fatalf("adjust stock status = %d", adjusted.StatusCode)
	}

	customerResponse := request(t, client, http.MethodPost, server.URL+"/api/v1/customer-accounts", tokens.AccessToken, map[string]any{
		"name": "Test Customer", "phone": "+254700000001", "email": "customer@example.test", "creditLimitMinor": 1000,
	})
	if customerResponse.StatusCode != http.StatusCreated {
		t.Fatalf("create customer status = %d", customerResponse.StatusCode)
	}
	customer := decodeResponse[customerAccountDTO](t, customerResponse)
	if _, err := db.Exec(`UPDATE customers SET balance_minor = 300 WHERE id = ?`, customer.ID); err != nil {
		t.Fatal(err)
	}
	payment := request(t, client, http.MethodPost, server.URL+"/api/v1/customer-account-payments", tokens.AccessToken, map[string]any{
		"customerId": customer.ID, "amountMinor": 100, "method": "mobile", "reference": "MPESA-1",
	})
	if payment.StatusCode != http.StatusCreated {
		t.Fatalf("receive account payment status = %d", payment.StatusCode)
	}
	updatedCustomer := decodeResponse[customerAccountDTO](t, payment)
	if updatedCustomer.Balance != 200 {
		t.Fatalf("customer balance = %d, want 200", updatedCustomer.Balance)
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
