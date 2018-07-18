rem "argl topdir/lib/**/*.tcl topdir/lib/**/*.tm |argd **/pkgIndex.tcl |argu |bd **/pkgIndex.tcl"
@gvim -p3 -c "argl topdir/lib/**/*.tcl topdir/lib/**/*.tm" +tabn -c "argl ./**/*.test" +tabn -c "argl ./**/testreport.txt" +tabn
