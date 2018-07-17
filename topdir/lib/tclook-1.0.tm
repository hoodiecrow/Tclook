package require Tk
package require textutil::adjust

namespace eval tclook {}

proc ::tclook::show args {
    # Takes a mode and a list of names, and attempts to resove each name as a
    # qualified command name, and to open a toplevel pane for each name
    # containing a list of information for it regarded as an object, a class, a
    # namespace, or a procedure.
    foreach name [lassign $args mode] {
        set get ::tclook::[string totitle $mode]::get
        if {[namespace exists $name]} {
            $get [list namespace $name]
        } else {
            set name [uplevel 1 [list namespace which $name]]
            if {[info object isa object $name]} {
                $get [list object $name]
                if {[info object isa class $name]} {
                    $get [list class $name]
                }
            } else {
                $get [list command $name]
            }
        }
    }
}

proc ::tclook::_text args {
    set info [Dict {*}$args]
    if {$info eq {}} {
        return
    }
    lassign [dict get $info title] - title
    lassign [dict get $info type] - type
    Print $type [lindex $title 1]
    puts {}
}

proc ::tclook::clearAll {} {
    # Close any still-open panes that have been opened by us.
    ::tclook::Pane::Clear
}

namespace eval ::tclook::Dict {

    proc get key {
        variable infoDict
        if {![dict exists $infoDict $key]} {
            dict set infoDict $key [[lindex $key 0] $key]
        }
        dict get $infoDict $key
    }

    proc object key {
        lassign $key type obj
        # TODO decide about other subcommands
        dict set result title S $key
        dict set result type S $type
        dict set result name S $obj
        dict set result isa S [GetIsa $obj]
        foreach key {class namespace} {
            dict set result $key S [info $type $key $obj]
        }
        foreach key {mixins filters variables vars} {
            dict set result $key L [info $type $key $obj]
        }
        dict set result methods L [info $type methods $obj -all -private]
    }

    proc class key {
        lassign $key type obj
        # TODO decide about other subcommands
        dict set result title S $key
        dict set result type S $type
        dict set result name S $obj
        dict set result superclass S [info $type superclass $obj]
        foreach key {mixins filters variables instances} {
            dict set result $key L [info $type $key $obj]
        }
        dict set result methods L [info $type methods $obj -all -private]
    }

    proc namespace key {
        lassign $key type obj
        dict set result title S $key
        dict set result type S $type
        dict set result name S $obj
        dict set result vars L [info vars $obj\::*]
        dict set result procs L [info procs $obj\::*]
        dict set result commands L [info commands $obj\::*]
        dict set result children L [::namespace children $obj]
    }

    proc method key {
        lassign $key type data
        dict set result title S $key
        dict set result type S $type
        # Note that type changes meaning here, from pane type to info subcommand name.
        lassign $data type obj name
        dict set result mtype S [info $type methodtype $obj $name]
        dict set result name S $name
        lassign [info $type definition $obj $name] args body
        dict set result args S $args
        dict set result body S [string trimright [::textutil::adjust::undent $body\x7f] \x7f]
    }

    proc command key {
        lassign $key type name
        dict set result title S $key
        dict set result type S $type
        dict set result name S $name
        dict set result args S [info args $name]
        dict set result body S [string trimright [::textutil::adjust::undent [info body $name]\x7f] \x7f]
    }

    proc GetIsa obj {
        lmap i {class metaclass object} {
            if {[info object isa $i $obj]} {set i} continue
        }
    }

    proc Init {} {
        variable infoDict {}
    }

}

namespace eval ::tclook::Print {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Print
    }
    namespace ensemble create -map $map

    proc objectPrint data {
        set info [::tclook::Dict object $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc classPrint data {
        set info [::tclook::Dict class $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc namespacePrint data {
        set info [::tclook::Dict namespace $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc methodPrint data {
        set info [::tclook::Dict method $data]
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            puts "$mtype $name {$args} {$body}"
        }
    }

    proc commandPrint name {
        if {$name in [info procs [namespace qualifiers $name]::*]} {
            set info [::tclook::Dict command $name]
            set info [dict map {- val} $info {lindex $val 1}]
            dict with info {
                puts "proc $name {$args} {$body}"
            }
        }
    }

}

namespace eval ::tclook::Pane {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Pane
    }
    namespace ensemble create -map $map

    proc get key {
        variable panes
        if {![info exists panes($key)] || ![winfo exists $panes($key)]} {
            set w [::tclook::Pane::GetPane $key]
            if {$w eq {}} {
                # Fail quietly if no info found.
                return
            }
            set panes($key) $w
        }
        # If we are still here, we now have a window. Bring it up.
        raise $panes($key)
        focus $panes($key)
    }

    proc objectPane {info pane} {
        set type object
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add isa  [dict get $info isa]
        foreach key {class namespace} {
            $pane add $key [dict get $info $key] Bind $key
        }
        $pane add mixins
        foreach val [dict get $info mixins] {
            $pane add {} $val Bind
        }
        $pane add filters
        foreach val [dict get $info filters] {
            $pane add {} $val BindMethod 0 0 $type [dict get $info name] $val
        }
        foreach key {variables vars} {
            $pane add $key
            foreach val [dict get $info $key] {
                $pane add {} $val
            }
        }
        $pane add methods
        foreach val [dict get $info methods] {
            $pane add {} $val BindMethod $type [dict get $info name] $val
        }
    }

    proc classPane {info pane} {
        set type class
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add superclass [dict get $info superclass] Bind class
        $pane add mixins
        foreach val [dict get $info mixins] {
            $pane add {} $val Bind
        }
        $pane add filters
        foreach val [dict get $info filters] {
            $pane add {} $val BindMethod 0 0 $type [dict get $info name] $val
        }
        $pane add variables
        foreach val [dict get $info variables] {
            $pane add {} $val
        }
        $pane add instances
        foreach val [dict get $info instances] {
            $pane add {} $val Bind
        }
        $pane add methods
        foreach val [dict get $info methods] {
            $pane add {} $val BindMethod $type [dict get $info name] $val
        }
    }

    proc namespacePane {info pane} {
        set type namespace
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add vars
        foreach val [dict get $info vars] {
            $pane add {} $val
        }
        $pane add commands
        foreach val [dict get $info commands] {
            if {$val in [dict get $info procs]} {
                $pane add {} $val Bind command
            } else {
                $pane add {} $val
            }
        }
        $pane add children
        foreach val [dict get $info children] {
            $pane add {} $val Bind namespace
        }
    }

    proc methodPane {info pane} {
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            $pane add "$mtype $name {$args} {$body}" -
        }
    }

    proc commandPane {info pane} {
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            $pane add "proc $name {$args} {$body}" -
        }
    }

    proc GetPane key {
        variable wn
        set info [::tclook::Dict::get $key]
        if {$info eq {}} {
            # Fail quietly if no info found.
            return
        }
        lassign $key type
        set w [toplevel .t[incr wn]]
        wm minsize $w 270 200
        wm title $w $key
        set frame [ttk::frame $w.f]
        pack $frame -expand yes -fill both
        set pane [PaneMaker new $frame]
        ::tclook::Pane $type $info $pane
        catch { $pane destroy }
        grid columnconfigure $frame 1 -weight 1
        foreach ch [winfo children $frame] {
            if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
                $ch config -style $type.TLabel
            }
        }
        return $w
    }

    oo::class create PaneMaker {
        variable frame rownum
        constructor args {
            lassign $args frame
        }
        method add {key {val {}} args} {
            incr rownum
            set k [ttk::label $frame.k$rownum -text $key]
            if {$val eq "-"} {
                set v -
            } else {
                set v [ttk::label $frame.v$rownum -text $val]
            }
            grid $k $v -sticky ew
            if {[llength $args] > 0} {
                namespace eval ::tclook [linsert $args 1 $v]
            }
            return $v
        }
    }

    proc Clear {{pattern *}} {
        variable panes
        foreach name [array names panes $pattern] {
            destroy $panes($name)
            array unset panes $name
        }
    }

    proc Init {} {
        variable panes
        if {[info exists panes]} {
            Clear
        } else {
            array set panes {}
        }
    }

}

namespace eval ::tclook::Page {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Page
    }
    namespace ensemble create -map $map

    proc commandPage info {
        variable pWin
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            $pWin.page delete 1.0 end
            $pWin.page insert end "proc $name\n" heading1
            $pWin.page insert end "proc $name {$args} {$body}"
        }
    }

    proc Open info {
        if {$info eq {}} {
            return
        }
        variable pWin
        if {![winfo exists $pWin]} {
            set pWin [toplevel .pwin]
            text $pWin.page
            pack $pWin.page -expand yes -fill both
        }
        variable pInfo
        lassign [dict get $info title] - title
        lassign [dict get $info type] - type
        if {![dict exists $pInfo $title]} {
            dict set pInfo $title [dict filter $info script {key -} {expr {$key ne "title"}}]
        }
        ${type}Page [dict get $pInfo $title]
    }

    proc Init {} {
        variable pWin
        catch { destroy $pWin }
        set pWin {}
        unset -nocomplain pWin
        variable pInfo {}
    }

}

proc ::tclook::BindMethod {w args} {
    if {[llength $args] eq 5} {
        set args [lassign $args p l]
    } else {
        set p [IsPrivate {*}$args]
        set l [IsLocal {*}$args]
    }
    $w config -style [lindex $args 0]$p$l.TLabel
    if no {
        bind $w <1> [list ::tclook::_pane method $args]
    }
    bind $w <1> [list ::tclook::Pane::get [list method $args]]
    $w config -cursor hand2
}

proc ::tclook::Bind {w {label wobj} {cursor hand2}} {
    if {$label ni {name isa}} {
        bindtags $w [linsert [bindtags $w] 0 ${label}Popup]
        $w config -cursor $cursor
    }
}

proc ::tclook::IsPrivate {type obj m} {
    expr {$m ni [concat [info $type methods $obj] [info $type methods $obj -all]]}
}

proc ::tclook::IsLocal {type obj m} {
    expr {$m in [concat [info $type methods $obj] [info $type methods $obj -private]]}
}

# TODO one-window version: as hypertext? 

# TODO have Dict object/class gather up plain, -private, -all, and -private -all lists and add checkboxes to the frame to select which list to use instead of changing font

proc ::tclook::Init {} {
    # TODO this method needs an overhaul
    ::tclook::Dict::Init
    ::tclook::Pane::Init
    ::tclook::Page::Init
    foreach {style color} {
        object wheat
        object00 wheat
        object01 wheat
        object10 wheat
        object11 wheat
        class lavender
        class00 lavender
        class01 lavender
        class10 lavender
        class11 lavender
        namespace DarkSeaGreen1
        method {lemon chiffon}
        command khaki1
    } {
        ttk::style configure $style.TLabel -background $color
    }
    foreach f {00 01 10 11 me} {
        set font$f [font create]
    }
    set fontdict [font actual [ttk::style lookup TLabel -font]]
    font configure $font00 {*}[dict merge $fontdict {-underline 1}]
    font configure $font01 {*}$fontdict
    font configure $font10 {*}[dict merge $fontdict {-slant italic -underline 1}]
    font configure $font11 {*}[dict merge $fontdict {-slant italic}]
    foreach type {object class} {
        foreach f {00 01 10 11} {
            ttk::style configure $type$f.TLabel -font [set font$f]
        }
    }
    font configure $fontme {*}[dict merge $fontdict {-family courier -size 11}]
    ttk::style configure method.TLabel -font $fontme

    bind wobjPopup <1> {::tclook::show pane [%W cget -text]}
    foreach tag {classPopup mixinsPopup superclassPopup} {
        bind $tag <1> {::tclook::Pane::get [list class [%W cget -text]]}
    }
    foreach tag {namespace command} {
        bind ${tag}Popup <1> [format {::tclook::Pane::get [list %s [%%W cget -text]]} $tag]
    }
}

::tclook::Init

return

package require log
cd ~/code/Modules/
tcl::tm::path add topdir/lib/
package require tclook
::log::lvSuppressLE i 0
catch { ::tclook::Pane::PaneMaker destroy } ; ::tclook::clearAll ; package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
::tclook::show pane oo::class ::tcl

