package main

import (
	"encoding/json"
	"fmt"
)

type User struct {
	Name string `json:"name"`
	Age  int    `json:"age"`
}

type Data struct {
	Users []User `json:"users"`
	Count int    `json:"count"`
}

func main() {
	data := []byte(`{"users": [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}], "count": 2}`)

	for i := 0; i < 10000; i++ {
		var parsed Data
		json.Unmarshal(data, &parsed)
		_ = parsed.Users[0].Name
	}

	fmt.Println("JSON parsed 10000 times")
}
