package main

import "testing"

func TestPasses(t *testing.T) {
	if Add(1, 2) != 3 {
		t.Fatal("expected 3")
	}
}

func TestFails(t *testing.T) {
	if Add(1, 2) != 4 {
		t.Fatal("expected 4")
	}
}
