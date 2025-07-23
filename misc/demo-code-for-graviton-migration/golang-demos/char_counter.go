package main

import (
	"fmt"
	"os"
	"sort"
)

// countCharacters counts the frequency of each character in a string
func countCharacters(input string) map[rune]int {
	charCount := make(map[rune]int)
	
	for _, char := range input {
		charCount[char]++
	}
	
	return charCount
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run char_counter.go <string>")
		os.Exit(1)
	}

	input := os.Args[1]
	charCount := countCharacters(input)
	
	fmt.Println("Character frequency in:", input)
	
	// Create a sorted list of characters for consistent output
	var chars []rune
	for char := range charCount {
		chars = append(chars, char)
	}
	sort.Slice(chars, func(i, j int) bool {
		return chars[i] < chars[j]
	})
	
	// Print the character counts
	for _, char := range chars {
		fmt.Printf("'%c': %d\n", char, charCount[char])
	}
}
