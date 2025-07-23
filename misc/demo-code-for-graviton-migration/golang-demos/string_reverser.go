package main

import (
	"fmt"
	"os"
)

// reverseString reverses a string
func reverseString(input string) string {
	runes := []rune(input)
	length := len(runes)
	
	// Swap characters from both ends moving toward the middle
	for i, j := 0, length-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}
	
	return string(runes)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run string_reverser.go <string>")
		os.Exit(1)
	}

	input := os.Args[1]
	fmt.Println("Original:", input)
	fmt.Println("Reversed:", reverseString(input))
}
