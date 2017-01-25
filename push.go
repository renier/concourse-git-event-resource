package main

import (
	"io/ioutil"
	"log"
	"os"
	"strconv"

	"github.com/bradfitz/gomemcache/memcache"
)

func main() {
	bytes, err := ioutil.ReadFile(os.Args[3])
	if err != nil {
		log.Fatal(err)
	}

	mc := memcache.New(os.Args[1])
	item := &memcache.Item{Key: os.Args[2], Value: bytes}
	if len(os.Args) > 4 {
		expiration, err2 := strconv.Atoi(os.Args[4])
		if err2 != nil {
			log.Fatal(err2)
		}

		item.Expiration = int32(expiration)
	}

	err = mc.Set(item)
	if err != nil {
		log.Fatal(err)
	}
}
