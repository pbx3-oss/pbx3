package main

import (
	"crypto/rand"
	"flag"
	"fmt"
	"math/big"
	"os"
	"strings"
	"unicode"
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

func charsetHasLetter(charset string) bool {
	for _, r := range charset {
		if unicode.IsLetter(r) {
			return true
		}
	}
	return false
}

func hasLetter(s string) bool {
	for _, r := range s {
		if unicode.IsLetter(r) {
			return true
		}
	}
	return false
}

// GenerateIDWithLetterPolicy regenerates until the ID contains at least one letter
// when the charset includes letters (so all-digit shortuids never escape). Digit-only
// charsets are unchanged. Caps attempts to avoid a pathological hang.
func GenerateIDWithLetterPolicy(length int, charset string, maxAttempts int) (string, error) {
	if maxAttempts <= 0 {
		maxAttempts = 64
	}
	requireLetter := charsetHasLetter(charset)
	var last string
	for attempt := 0; attempt < maxAttempts; attempt++ {
		id, err := GenerateID(length, charset)
		if err != nil {
			return "", err
		}
		last = id
		if !requireLetter || hasLetter(id) {
			return id, nil
		}
	}
	return "", fmt.Errorf("could not generate ID with a letter after %d attempts (last=%q)", maxAttempts, last)
}

func main() {

	// Defaults preserve existing behaviour when no flags are provided.
	// Shortuid profile: 6 chars, DNS-safe (lowercase + digits, no vowels / ambiguous glyphs).
	defaultLength := 6
	defaultCharset := "0123456789bcdfghjkmnpqrstvwxyz"

	length := flag.Int("length", defaultLength, "length of the generated ID (must be > 0)")
	charset := flag.String("charset", defaultCharset, "characters to use when generating the ID")
	flag.Parse()

	id, err := GenerateIDWithLetterPolicy(*length, *charset, 64)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}

	// Default charset is lowercase-only; force lower so callers cannot inject uppercase via a stale binary.
	if *charset == defaultCharset {
		id = strings.ToLower(id)
	}

	fmt.Println(id)
}
