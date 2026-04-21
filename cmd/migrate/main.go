package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func main() {
	entries, err := os.ReadDir("migrations")
	if err != nil {
		log.Fatal(err)
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		fmt.Println(filepath.Join("migrations", entry.Name()))
	}
}
