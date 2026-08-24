package main

import (
	"log"
	"os"
	"webproject/config"
	"webproject/routes"

	"github.com/joho/godotenv"
	"github.com/sirupsen/logrus"
)

func main() {
	if err := godotenv.Load(); err != nil {
		logrus.Warn("No .env file found, using system environment variables")
	}
	logrus.SetFormatter(&logrus.JSONFormatter{})
	logrus.Info("Application started")

	config.InitDatabase()
	r := routes.SetupRoutes()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	port = ":" + port

	logrus.WithField("port", port).Info("Server starting")

	if err := r.Run(port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
