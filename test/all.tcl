package require tcltest

set ::DIRS(test) [file dirname [file normalize [info script]]]
set ::DIRS(base) [file dirname $::DIRS(test)]
set ::project    [string tolower [file tail $::DIRS(base)]]
set ::DIRS(lib)  [file join $::DIRS(base) topdir lib]

set outfile [file join $::DIRS(test) testreport.txt]
set errfile [file join $::DIRS(test) testerrors.txt]
file delete -force $outfile $errfile

lappend ::argv -testdir $::DIRS(test)
lappend ::argv -outfile $outfile
lappend ::argv -errfile $errfile
lappend ::argv -tmpdir [file join $::DIRS(test) temp]
lappend ::argv -load [subst -noc {
    ::tcl::tm::path add $::DIRS(lib)
    set ::auto_path [linsert \$::auto_path 0 $DIRS(lib)]
    package require $::project
    package require log
}]

::tcltest::configure {*}$::argv
::tcltest::runAllTests
