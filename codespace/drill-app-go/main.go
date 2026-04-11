package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

var pool *pgxpool.Pool

type Product struct {
	ID        int    `json:"id"`
	SKU       string `json:"sku"`
	Name      string `json:"name"`
	Category  string `json:"category"`
	Warehouse string `json:"warehouse"`
	Quantity  int    `json:"quantity"`
}

func main() {
	ctx := context.Background()

	var err error
	pool, err = connectDB(ctx)
	if err != nil {
		log.Fatalf("database connection failed: %v", err)
	}
	defer pool.Close()

	if err := initDB(ctx); err != nil {
		log.Fatalf("database init failed: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleLiveness)
	mux.HandleFunc("GET /readyz", handleReadiness)
	mux.HandleFunc("GET /api/v1/products", handleListProducts)
	mux.HandleFunc("GET /api/v1/products/{id}", handleGetProduct)
	mux.HandleFunc("POST /api/v1/products", handleCreateProduct)
	mux.HandleFunc("GET /", handleRoot)

	port := os.Getenv("LISTEN_PORT")
	if port == "" {
		port = "9090"
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("shutting down...")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		srv.Shutdown(shutdownCtx)
	}()

	log.Printf("listening on :%s", port)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}

func connectDB(ctx context.Context) (*pgxpool.Pool, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=disable",
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
	)
	p, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	if err := p.Ping(ctx); err != nil {
		p.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return p, nil
}

func initDB(ctx context.Context) error {
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS products (
			id        SERIAL PRIMARY KEY,
			sku       VARCHAR(20) NOT NULL,
			name      VARCHAR(120) NOT NULL,
			category  VARCHAR(60) NOT NULL,
			warehouse VARCHAR(80),
			quantity  INTEGER DEFAULT 0
		)
	`)
	if err != nil {
		return fmt.Errorf("create table: %w", err)
	}

	var count int
	err = pool.QueryRow(ctx, "SELECT COUNT(*) FROM products").Scan(&count)
	if err != nil {
		return fmt.Errorf("count products: %w", err)
	}

	if count == 0 {
		_, err = pool.Exec(ctx, `
			INSERT INTO products (sku, name, category, warehouse, quantity) VALUES
			('WH-SRV-4820', 'Rack Server 2U', 'compute', 'DC-West-03', 48),
			('WH-SWT-1100', '48-Port Managed Switch', 'networking', 'DC-East-01', 15),
			('WH-PSU-7750', 'Redundant PSU 750W', 'power', 'DC-West-03', 120)
		`)
		if err != nil {
			return fmt.Errorf("seed products: %w", err)
		}
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	writeJSON(w, http.StatusOK, map[string]string{
		"app":      "inventory-api",
		"version":  "0.1.0",
		"hostname": hostname,
	})
}

func handleLiveness(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "alive"})
}

func handleReadiness(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := pool.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "not ready",
			"error":  err.Error(),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func handleListProducts(w http.ResponseWriter, r *http.Request) {
	rows, err := pool.Query(r.Context(),
		"SELECT id, sku, name, category, warehouse, quantity FROM products ORDER BY id")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	products := []Product{}
	for rows.Next() {
		var p Product
		if err := rows.Scan(&p.ID, &p.SKU, &p.Name, &p.Category, &p.Warehouse, &p.Quantity); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		products = append(products, p)
	}
	writeJSON(w, http.StatusOK, products)
}

func handleGetProduct(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
		return
	}

	var p Product
	err = pool.QueryRow(r.Context(),
		"SELECT id, sku, name, category, warehouse, quantity FROM products WHERE id = $1", id,
	).Scan(&p.ID, &p.SKU, &p.Name, &p.Category, &p.Warehouse, &p.Quantity)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func handleCreateProduct(w http.ResponseWriter, r *http.Request) {
	var input struct {
		SKU       string `json:"sku"`
		Name      string `json:"name"`
		Category  string `json:"category"`
		Warehouse string `json:"warehouse"`
		Quantity  int    `json:"quantity"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	var id int
	err := pool.QueryRow(r.Context(),
		"INSERT INTO products (sku, name, category, warehouse, quantity) VALUES ($1,$2,$3,$4,$5) RETURNING id",
		input.SKU, input.Name, input.Category, input.Warehouse, input.Quantity,
	).Scan(&id)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]int{"id": id})
}
