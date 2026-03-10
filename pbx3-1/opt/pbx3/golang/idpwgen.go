package main

import (
	"crypto/rand"
	"flag"
	"fmt"
	"math/big"
	"os"
)

func GenerateID(length int, charset string) (string, error) {

	if length <= 0 {
		return "", fmt.Errorf("length must be > 0")
	}

	if len(charset) == 0 {
		return "", fmt.Errorf("charset cannot be empty")
	}

	result := make([]byte, length)
	max := big.NewInt(int64(len(charset)))

	for i := 0; i < length; i++ {
		n, err := rand.Int(rand.Reader, max)
		if err != nil {
			return "", err
		}

		result[i] = charset[n.Int64()]
	}

	return string(result), nil
}

func main() {

	// Defaults preserve existing behaviour when no flags are provided.
	defaultLength := 6
	defaultCharset := "0123456789bcdfghjkmnpqrstvwxyz"

	length := flag.Int("length", defaultLength, "length of the generated ID (must be > 0)")
	charset := flag.String("charset", defaultCharset, "characters to use when generating the ID")
	flag.Parse()

	id, err := GenerateID(*length, *charset)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}

	fmt.Println(id)
}