package libtorrent

import (
	"fmt"
)

// catch will recover from a panic and store the recover message to the error
// parameter. The error must be passed by reference in order to be returned to the
// calling function.
func catch(err *error) {
	if r := recover(); r != nil {
		*err = fmt.Errorf("%v", r)
	}
}
