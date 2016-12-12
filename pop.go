package main

import (
	"fmt"
	"log"
	"os"

	"github.com/bradfitz/gomemcache/memcache"
)

func main() {
	if len(os.Args) < 3 {
		log.Fatalf("usage: %s <queue address:port> <queue name>\n", os.Args[0])
	}

	queueAddr := os.Args[1]
	queueName := os.Args[2]

	mc := memcache.New(queueAddr)
	it, err := mc.Get(queueName)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println(string(it.Value))
}
