package config

import (
	"errors"
	"os"
	"strings"
)

type Config struct {
	Address        string
	DatabasePath   string
	JWTSecret      []byte
	BootstrapToken string
	CORSOrigins    map[string]struct{}
}

func Load() (Config, error) {
	secret := os.Getenv("JWT_SECRET")
	if len(secret) < 32 {
		return Config{}, errors.New("JWT_SECRET must contain at least 32 characters")
	}
	bootstrapToken := os.Getenv("BOOTSTRAP_TOKEN")
	if len(bootstrapToken) < 32 {
		return Config{}, errors.New("BOOTSTRAP_TOKEN must contain at least 32 characters")
	}

	address := strings.TrimSpace(os.Getenv("API_ADDRESS"))
	if address == "" {
		address = ":8080"
	}
	databasePath := strings.TrimSpace(os.Getenv("DATABASE_PATH"))
	if databasePath == "" {
		databasePath = "data/pharmacy.db"
	}

	origins := make(map[string]struct{})
	for _, origin := range strings.Split(os.Getenv("CORS_ORIGINS"), ",") {
		if origin = strings.TrimSpace(origin); origin != "" {
			origins[origin] = struct{}{}
		}
	}

	return Config{
		Address:        address,
		DatabasePath:   databasePath,
		JWTSecret:      []byte(secret),
		BootstrapToken: bootstrapToken,
		CORSOrigins:    origins,
	}, nil
}
