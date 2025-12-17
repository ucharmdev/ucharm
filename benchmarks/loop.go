package main

import "fmt"

func main() {
	total := 0
	for i := 0; i < 1000000; i++ {
		total += i
	}
	fmt.Printf("sum(0..999999) = %d\n", total)
}
