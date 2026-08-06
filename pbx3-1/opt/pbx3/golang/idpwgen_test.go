package main

import (
	"strings"
	"testing"
	"unicode"
)

func TestGenerateIDWithLetterPolicyRejectsAllDigit(t *testing.T) {
	charset := "0123456789bcdfghjkmnpqrstvwxyz"
	for i := 0; i < 200; i++ {
		id, err := GenerateIDWithLetterPolicy(6, charset, 64)
		if err != nil {
			t.Fatalf("attempt %d: %v", i, err)
		}
		if len(id) != 6 {
			t.Fatalf("length=%d want 6 id=%q", len(id), id)
		}
		hasL := false
		for _, r := range id {
			if unicode.IsLetter(r) {
				hasL = true
				break
			}
		}
		if !hasL {
			t.Fatalf("all-digit id escaped: %q", id)
		}
	}
}

func TestGenerateIDDigitOnlyCharsetUnchanged(t *testing.T) {
	id, err := GenerateIDWithLetterPolicy(6, "0123456789", 8)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Trim(id, "0123456789") != "" {
		t.Fatalf("expected digits only, got %q", id)
	}
}
