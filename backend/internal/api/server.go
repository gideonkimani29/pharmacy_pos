package api

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"pharmacy-pos/backend/internal/config"
)

type actor struct {
	ID    string
	Name  string
	Email string
	Role  string
}

type actorContextKey struct{}

type Server struct {
	db  *sql.DB
	cfg config.Config
	mux *http.ServeMux
}

func New(db *sql.DB, cfg config.Config) http.Handler {
	s := &Server{db: db, cfg: cfg, mux: http.NewServeMux()}
	s.routes()
	return s.cors(s.mux)
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /health", s.health)
	s.mux.HandleFunc("POST /api/v1/auth/bootstrap", s.bootstrap)
	s.mux.HandleFunc("POST /api/v1/auth/login", s.login)
	s.mux.HandleFunc("POST /api/v1/auth/refresh", s.refresh)
	s.mux.HandleFunc("POST /api/v1/auth/logout", s.logout)

	s.handle("GET /api/v1/products", s.products)
	s.handle("GET /api/v1/products/barcode/{barcode}", s.productByBarcode)
	s.handle("POST /api/v1/sales", s.submitSale)
	s.handle("GET /api/v1/customers", s.customers)
	s.handle("GET /api/v1/dashboard/summary", s.dashboard)
	s.handle("GET /api/v1/medicines", s.listMedicines)
	s.handle("POST /api/v1/medicines", s.createMedicine)
	s.handle("PUT /api/v1/medicines/{id}", s.updateMedicine)
	s.handle("PATCH /api/v1/medicines/{id}/active", s.setMedicineActive)
	s.handle("GET /api/v1/stock/batches", s.listBatches)
	s.handle("POST /api/v1/stock/adjustments", s.adjustStock)
	s.handle("GET /api/v1/customer-accounts", s.listCustomerAccounts)
	s.handle("POST /api/v1/customer-accounts", s.createCustomerAccount)
	s.handle("PUT /api/v1/customer-accounts/{id}", s.updateCustomerAccount)
	s.handle("PATCH /api/v1/customer-accounts/{id}/active", s.setCustomerAccountActive)
	s.handle("POST /api/v1/customer-account-payments", s.receiveAccountPayment)
	s.handle("GET /api/v1/suppliers", s.listSuppliers)
	s.handle("GET /api/v1/purchases", s.listPurchases)
	s.handle("POST /api/v1/purchases", s.recordPurchase)
	s.handle("GET /api/v1/reports/sales", s.salesReport)
	s.handle("GET /api/v1/reports/profit", s.profitReport)
	s.handle("GET /api/v1/reports/losses", s.lossesReport)
	s.handle("GET /api/v1/settings", s.getSettings)
	s.handle("PUT /api/v1/settings", s.saveSettings)
	s.handle("GET /api/v1/users", s.listUsers)
	s.handle("POST /api/v1/users", s.createUser)
	s.handle("PUT /api/v1/users/{id}", s.updateUser)
	s.handle("PATCH /api/v1/users/{id}/active", s.setUserActive)
}

func (s *Server) handle(pattern string, fn http.HandlerFunc) {
	s.mux.Handle(pattern, s.authenticate(fn))
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.db.PingContext(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "Database is unavailable.", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			if _, allowed := s.cfg.CORSOrigins[origin]; !allowed {
				writeError(w, http.StatusForbidden, "origin_not_allowed", "Origin is not allowed.", nil)
				return
			}
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Add("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		if !strings.HasPrefix(header, "Bearer ") {
			writeError(w, http.StatusUnauthorized, "unauthorized", "A bearer access token is required.", nil)
			return
		}
		userID, err := s.verifyAccessToken(strings.TrimSpace(strings.TrimPrefix(header, "Bearer ")))
		if err != nil {
			writeError(w, http.StatusUnauthorized, "unauthorized", "Access token is invalid or expired.", nil)
			return
		}
		var user actor
		var active int
		err = s.db.QueryRowContext(r.Context(), `SELECT id, name, email, role, active FROM users WHERE id = ?`, userID).
			Scan(&user.ID, &user.Name, &user.Email, &user.Role, &active)
		if err != nil || active != 1 {
			writeError(w, http.StatusUnauthorized, "unauthorized", "User is unavailable.", nil)
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), actorContextKey{}, user)))
	})
}

func currentActor(r *http.Request) actor {
	value, _ := r.Context().Value(actorContextKey{}).(actor)
	return value
}

func (s *Server) requireRole(w http.ResponseWriter, r *http.Request, allowed ...string) bool {
	role := currentActor(r).Role
	for _, candidate := range allowed {
		if role == candidate {
			return true
		}
	}
	writeError(w, http.StatusForbidden, "forbidden", "Your role cannot perform this action.", nil)
	return false
}

func (s *Server) accessToken(user actor) (string, error) {
	now := time.Now().UTC()
	header, _ := json.Marshal(map[string]string{"alg": "HS256", "typ": "JWT"})
	payload, err := json.Marshal(map[string]any{
		"sub": user.ID, "role": user.Role, "iat": now.Unix(), "exp": now.Add(15 * time.Minute).Unix(),
	})
	if err != nil {
		return "", err
	}
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	mac := hmac.New(sha256.New, s.cfg.JWTSecret)
	_, _ = mac.Write([]byte(unsigned))
	signature := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	return unsigned + "." + signature, nil
}

func (s *Server) verifyAccessToken(token string) (string, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", errors.New("invalid token")
	}
	unsigned := parts[0] + "." + parts[1]
	mac := hmac.New(sha256.New, s.cfg.JWTSecret)
	_, _ = mac.Write([]byte(unsigned))
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || !hmac.Equal(signature, mac.Sum(nil)) {
		return "", errors.New("invalid signature")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", errors.New("invalid payload")
	}
	var claims struct {
		Subject string `json:"sub"`
		Expires int64  `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil || claims.Subject == "" || claims.Expires <= time.Now().Unix() {
		return "", errors.New("expired token")
	}
	return claims.Subject, nil
}

func randomID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("generate ID: %w", err)
	}
	return fmt.Sprintf("%x", bytes), nil
}

func hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return fmt.Sprintf("%x", hash[:])
}

func newOpaqueToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("generate refresh token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeRawJSON(w http.ResponseWriter, status int, value []byte) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write(value)
}

func writeError(w http.ResponseWriter, status int, code, message string, details any) {
	writeJSON(w, status, map[string]any{
		"error": map[string]any{"code": code, "message": message, "details": details},
	})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "Request body must be valid JSON.", nil)
		return false
	}
	var trailing any
	if err := decoder.Decode(&trailing); err == nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "Request body must contain one JSON value.", nil)
		return false
	}
	return true
}

func methodNotAllowed(w http.ResponseWriter) {
	writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "Method is not allowed.", nil)
}
