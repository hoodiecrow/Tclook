package require tcltest

set testdir [file normalize [file dirname [info script]]]
set outfile [file join $testdir testreport.txt]
set errfile [file join $testdir testerrors.txt]
file delete -force $outfile $errfile

::tcltest::configure {*}$::argv -encoding utf-8

::tcltest::configure -testdir $testdir -outfile $outfile -errfile $errfile
::tcltest::configure -tmpdir [file join $testdir temp]
::tcltest::configure -loadfile [file join $testdir common.tcl]

::tcltest::runAllTests
