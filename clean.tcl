package require fileutil

set dir [file dirname [info script]]
file delete -force {*}[::fileutil::findByPattern $dir *~] {*}[glob -nocomplain -dir $dir/test _AUTOGEN.*]

exit
