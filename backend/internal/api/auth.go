package api

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type tokenResponse struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	TokenType    string `json:"tokenType"`
	ExpiresIn    int    `json:"expiresIn"`
}

func (s *Server) bootstrap(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		Phone    string `json:"phone"`
		Password string `json:"password"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	request.Name = strings.TrimSpace(request.Name)
	request.Email = strings.ToLower(strings.TrimSpace(request.Email))
	if request.Name == "" || !strings.Contains(request.Email, "@") || len(request.Password) < 12 {
		writeError(w, http.StatusBadRequest, "validation_error", "Name, valid email, and a password of at least 12 characters are required.", nil)
		return
	}
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(request.Password), bcrypt.DefaultCost)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create account.", nil)
		return
	}
	id, err := randomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create account.", nil)
		return
	}

	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create account.", nil)
		return
	}
	defer tx.Rollback()
	var count int
	if err := tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM users`).Scan(&count); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create account.", nil)
		return
	}
	if count != 0 {
		writeError(w, http.StatusConflict, "bootstrap_complete", "An administrator already exists.", nil)
		return
	}
	_, err = tx.ExecContext(r.Context(), `INSERT INTO users (id, name, email, phone, role, password_hash) VALUES (?, ?, ?, ?, 'admin', ?)`,
		id, request.Name, request.Email, strings.TrimSpace(request.Phone), string(passwordHash))
	if err != nil {
		writeError(w, http.StatusConflict, "account_exists", "Could not create the administrator account.", nil)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not create account.", nil)
		return
	}
	s.issueTokens(w, r, actor{ID: id, Name: request.Name, Email: request.Email, Role: "admin"}, http.StatusCreated)
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	var user actor
	var passwordHash string
	var active int
	err := s.db.QueryRowContext(r.Context(),
		`SELECT id, name, email, role, password_hash, active FROM users WHERE email = ? COLLATE NOCASE`,
		strings.TrimSpace(request.Email)).Scan(&user.ID, &user.Name, &user.Email, &user.Role, &passwordHash, &active)
	if err != nil || active != 1 || bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(request.Password)) != nil {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "Email or password is incorrect.", nil)
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `UPDATE users SET last_sign_in_at = ? WHERE id = ?`, time.Now().UTC().Format(time.RFC3339Nano), user.ID); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not sign in.", nil)
		return
	}
	s.issueTokens(w, r, user, http.StatusOK)
}

func (s *Server) issueTokens(w http.ResponseWriter, r *http.Request, user actor, status int) {
	access, err := s.accessToken(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not issue access token.", nil)
		return
	}
	refresh, err := newOpaqueToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not issue refresh token.", nil)
		return
	}
	expires := time.Now().UTC().Add(30 * 24 * time.Hour)
	if _, err := s.db.ExecContext(r.Context(),
		`INSERT INTO refresh_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)`,
		hashToken(refresh), user.ID, expires.Format(time.RFC3339Nano)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not issue refresh token.", nil)
		return
	}
	writeJSON(w, status, tokenResponse{AccessToken: access, RefreshToken: refresh, TokenType: "Bearer", ExpiresIn: 900})
}

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	var request struct {
		RefreshToken string `json:"refreshToken"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if strings.TrimSpace(request.RefreshToken) == "" {
		writeError(w, http.StatusUnauthorized, "invalid_refresh_token", "Refresh token is invalid or expired.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	defer tx.Rollback()

	var user actor
	var expiry string
	var active int
	err = tx.QueryRowContext(r.Context(), `SELECT u.id, u.name, u.email, u.role, u.active, t.expires_at
		FROM refresh_tokens t JOIN users u ON u.id = t.user_id WHERE t.token_hash = ?`, hashToken(request.RefreshToken)).
		Scan(&user.ID, &user.Name, &user.Email, &user.Role, &active, &expiry)
	if err != nil || active != 1 {
		writeError(w, http.StatusUnauthorized, "invalid_refresh_token", "Refresh token is invalid or expired.", nil)
		return
	}
	expiresAt, err := time.Parse(time.RFC3339Nano, expiry)
	if err != nil || !expiresAt.After(time.Now()) {
		_, _ = tx.ExecContext(r.Context(), `DELETE FROM refresh_tokens WHERE token_hash = ?`, hashToken(request.RefreshToken))
		writeError(w, http.StatusUnauthorized, "invalid_refresh_token", "Refresh token is invalid or expired.", nil)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `DELETE FROM refresh_tokens WHERE token_hash = ?`, hashToken(request.RefreshToken)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	access, err := s.accessToken(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	refresh, err := newOpaqueToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `INSERT INTO refresh_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)`,
		hashToken(refresh), user.ID, time.Now().UTC().Add(30*24*time.Hour).Format(time.RFC3339Nano)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not refresh session.", nil)
		return
	}
	writeJSON(w, http.StatusOK, tokenResponse{AccessToken: access, RefreshToken: refresh, TokenType: "Bearer", ExpiresIn: 900})
}

func (s *Server) logout(w http.ResponseWriter, r *http.Request) {
	var request struct {
		RefreshToken string `json:"refreshToken"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if _, err := s.db.ExecContext(r.Context(), `DELETE FROM refresh_tokens WHERE token_hash = ?`, hashToken(request.RefreshToken)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not sign out.", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) acceptInvitation(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Token    string `json:"token"`
		Password string `json:"password"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if request.Token == "" || len(request.Password) < 12 {
		writeError(w, http.StatusBadRequest, "validation_error", "A valid invitation and password of at least 12 characters are required.", nil)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not accept invitation.", nil)
		return
	}
	defer tx.Rollback()
	var userID, expires string
	if err := tx.QueryRowContext(r.Context(), `SELECT user_id, expires_at FROM user_invitations WHERE token_hash = ?`,
		hashToken(request.Token)).Scan(&userID, &expires); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_invitation", "Invitation is invalid or expired.", nil)
		return
	}
	expiry, err := time.Parse(time.RFC3339Nano, expires)
	if err != nil || !expiry.After(time.Now()) {
		_, _ = tx.ExecContext(r.Context(), `DELETE FROM user_invitations WHERE token_hash = ?`, hashToken(request.Token))
		writeError(w, http.StatusUnauthorized, "invalid_invitation", "Invitation is invalid or expired.", nil)
		return
	}
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(request.Password), bcrypt.DefaultCost)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not set password.", nil)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `UPDATE users SET password_hash = ? WHERE id = ? AND active = 1`,
		string(passwordHash), userID); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not set password.", nil)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `DELETE FROM user_invitations WHERE token_hash = ?`, hashToken(request.Token)); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not accept invitation.", nil)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "internal_error", "Could not accept invitation.", nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func isNotFound(err error) bool {
	return errors.Is(err, sql.ErrNoRows)
}
