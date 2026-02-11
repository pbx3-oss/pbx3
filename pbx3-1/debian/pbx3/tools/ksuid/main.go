// ksuid prints one K-Sortable Unique ID per line (27-char base62).
// Used by bash/PHP for instance id and DB id columns.
package main

import (
	"fmt"
	"github.com/segmentio/ksuid"
)

func main() {
	fmt.Println(ksuid.New().String())
}
