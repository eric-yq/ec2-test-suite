package main

import (
	"encoding/base64"
	"fmt"
	"os"
)

// encodeBase64 encodes a string to base64
func encodeBase64(input string) string {
	return base64.StdEncoding.EncodeToString([]byte(input))
}

// decodeBase64 decodes a base64 string
func decodeBase64(input string) (string, error) {
	decoded, err := base64.StdEncoding.DecodeString(input)
	if err != nil {
		return "", err
	}
	return string(decoded), nil
}

func main() {
	if len(os.Args) < 3 {
		fmt.Println("Usage: go run base64_encoder.go [encode|decode] <string>")
		os.Exit(1)
	}

	operation := os.Args[1]
	input := os.Args[2]

	switch operation {
	case "encode":
		fmt.Println("Original:", input)
		fmt.Println("Base64 encoded:", encodeBase64(input))
	case "decode":
		decoded, err := decodeBase64(input)
		if err != nil {
			fmt.Println("Error decoding:", err)
			os.Exit(1)
		}
		fmt.Println("Base64 decoded:", decoded)
	default:
		fmt.Println("Unknown operation. Use 'encode' or 'decode'")
		os.Exit(1)
	}
}
