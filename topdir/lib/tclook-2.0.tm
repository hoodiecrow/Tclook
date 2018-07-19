
namespace eval tclook {
    namespace export tclook
    variable view {}
}

# TclOO-based object/class/namespace browser

proc ::tclook::tclook args {
    # Ensure that a 'view' exists.
    # Figure out a key string for the thing.
    # Check if the asked-for item is already showing. If so, make it visible,
    # otherwise add it to the view.
    variable view
    if {$view eq {}} { set view [PrintView new] }
    set key [MakeKey [uplevel 1 {namespace current}] {*}$args]
    if {[$view exists $key]} {
        $view display $key
    } else {
        $view insert $key
    }
}

proc ::tclook::ResolveNamespace {ns args} {
    set _desc [namespace eval $ns [list namespace which {*}$args]]
    if {$_desc ne {}} {
        return $_desc
    } else {
        return [lindex $args end]
    }
}

proc ::tclook::MakeKey {ns args} {
    # Create an identifier for an item to be viewed. It will be a string that
    # is a proper list of 1) a thing type and 2) a qualified command name (for
    # object, class, namespace, command), a qualified variable name (for set),
    # or a method descriptor.
    switch [llength $args] {
        0 {
            return {class ::oo::class}
        }
        1 {
            # A single argument must be the name of an object, class, a
            # namespace, or a Tcl command procedure.
            # The slightly cumbersome test for a proc (instead of just [llength
            # [info procs $desc]] > 0) is to handle proc names that are glob
            # patterns.
            set desc [ResolveNamespace $ns [lindex $args 0]]
            if {[namespace exists $desc]} {
                return [list namespace $desc]
            } elseif {$desc in [info procs [namespace qualifiers $desc]::*]} {
                return [list command $desc]
            } elseif {[info object isa class $desc]} {
                return [list class $desc]
            } elseif {[info object isa object $desc]} {
                return [list object $desc]
            }
        }
        default {
            switch [lindex $args 0] {
                method {
                    set desc [lassign $args type]
                    return [list $type $desc]
                }
                set {
                    set type set
                    set desc [ResolveNamespace $ns -variable [lindex $args end]]
                    return [list $type $desc]
                }
                object -
                class -
                namespace -
                command {
                    set desc [ResolveNamespace $ns [lassign $args type]]
                    return [list $type $desc]
                }
            }
        }
    }
    return -code error [format {unknown key arguments "%s"} $args]
}

catch { ::tclook::PrintView destroy }
oo::class create ::tclook::PrintView {

    method exists key { expr 0 }

    forward display my insert
    forward replace my insert

    method insert key {
        lassign [::tclook::Values {*}$key] destination key0 values
        switch $destination {
            side {
                puts $values
            }
            main {
                puts $key0
                dict for {key1 items} $values {
                    puts "  [string totitle $key1]"
                    foreach item $items {
                        puts "    $item"
                    }
                }
            }
            none { ; }
        }
    }

}

catch { ::tclook::TreeView destroy }
oo::class create ::tclook::TreeView {
    variable main side bigfont

    constructor {{top .tclook}} {
        package require Tk
        # init widget
        destroy $top
        toplevel $top
        set main [ttk::treeview $top.main -show tree -yscroll [list $top.s1 set]]
        set s1 [ttk::scrollbar $top.s1 -orient vertical -command [list $main yview]]
        grid $main $s1 -sticky news
        set side [text $top.side -height 9 -width 30 -yscroll [list $top.s2 set]]
        set s2 [ttk::scrollbar $top.s2 -orient vertical -command [list $side yview]]
        grid $side $s2 -sticky news
        grid columnconfigure $top $main -weight 1
        grid rowconfigure $top $main -weight 1
        grid rowconfigure $top $side -weight 1
        # init widget data
        set bigfont [my MakeFont TkDefaultFont -weight bold -size 10]
        $main tag configure big -font $bigfont
        bind $main <<TreeviewSelect>> [namespace code [list my TreeviewSelect %W]]
    }

    destructor {
        font delete $bigfont
        catch { destroy [winfo parent $main] }
    }

    method TreeviewSelect w {
        # Handler for <<TreeviewSelect>> events. If the clicked-on item is a leaf
        # item, use the 'tclook' command with its text as argument list to add it to
        # the view.
        set item [$w focus]
        if {[$w tag has leaf $item]} {
            ::tclook::tclook {*}[$w item $item -text]
        } elseif {[$w tag has big $item]} {
            my replace [$w item $item -text]
        }
    }

    method MakeFont {name args} {
        # Create a new font based on a named font with the rest of the
        # arguments being font options.
        set font [font create]
        font configure $font {*}[dict merge [font actual $name] $args]
        return $font
    }

    method Insert {parent args} {
        $main insert $parent end {*}$args
    }

    method InsertValues {parent values} {
        dict for {key items} $values {
            set key1 [list $parent $key]
            my Insert $parent -id $key1 -text [string totitle $key]
            foreach item $items {
                my Insert $key1 -text $item -tags leaf
            }
        }
    }

    method exists key { $main exists $key }
    
    method insert key {
        log::log d [info level 0] 
        # If 'destination' is side, put 'values' in the side field. If it is
        # main, insert 'values' as an info dictionary into the view under the
        # key 'key0'.
        lassign [::tclook::Values {*}$key] destination key0 values
        switch $destination {
            side {
                $side delete 1.0 end
                $side insert end $values
            }
            main {
                my Insert {} -id $key0 -text $key0 -tags big
                my InsertValues $key0 $values
                my display $key0
            }
            none { ; }
        }
    }

    method replace key {
        lassign [::tclook::Values {*}$key] destination key0 values
        switch $destination {
            side {
                $side delete 1.0 end
                $side insert end $values
            }
            main {
                foreach child [$main children $key0] {
                    $main delete [list $child]
                }
                my InsertValues $key0 $values
                my display $key0
            }
            none { ; }
        }
    }

    method display key {
        $main see $key
        $main item $key -open true
    }

}

catch { ::tclook::Values destroy }
oo::object create ::tclook::Values
oo::objdefine ::tclook::Values {
    # The public methods are the kinds of things that the package can found out
    # info about. They return a tuple <dest,key0,values> where 'dest' is side,
    # main, or none. 'side' means to show text in a secondary space, 'main'
    # means to add info to the main display, and 'none' means that the output
    # should be suppressed. 'key0' only has meaning for 'dest'=main: it is the
    # string that future calls to '{view} exist' will use to determine if the
    # info should be displayed or inserted. 'values' is a dict of info about
    # the thing.

    method object desc {
        set type [self method]
        set key0 [list $type $desc]
        foreach key {methods namespace class mixins} {
            dict set values $key [switch $key {
                methods   { my Methods {*}$key0 }
                namespace { my AddPrefix $key [my Info $key0 $key] }
                class     -
                mixins    { my AddPrefix class [my Info $key0 $key] }
            }]
        }
        return [list main $key0 $values]
    }

    method class desc {
        set type [self method]
        set key0 [list $type $desc]
        foreach key {methods superclasses subclasses mixins instances} {
            dict set values $key [switch $key {
                methods      { my Methods {*}$key0 }
                superclasses -
                subclasses -
                mixins       { my AddPrefix $type [my Info $key0 $key] }
                instances    {
                    if {[info object isa metaclass $desc]} {
                        my AddPrefix class [my Info $key0 $key]
                    } else {
                        my AddPrefix object [my Info $key0 $key]
                    }
                }
            }]
        }
        return [list main $key0 $values]
    }

    method namespace desc {
        set type [self method]
        set key0 [list $type $desc]
        dict set values vars [my AddPrefix set [info vars $desc\::*]]
        dict set values commands [my AddPrefix command [info commands $desc\::*]]
        dict set values children [my AddPrefix $type [namespace children $desc]]
        return [list main $key0 $values]
    }

    method method desc {
        lassign $desc name - orig
        lassign $orig type defi
        return [list side {} [list method $name {*}[info $type definition $defi $name]]]
    }

    method command desc {
        try {
            list proc $desc [info args $desc] [info body $desc]
        } on ok values {
            return [list side {} $values]
        } on error {} {
            return [list side {} {}]
        }
    }

    method set desc {
        if {[array exists $desc]} {
            set d [lsort -dictionary -stride 2 -index 0 [array get $desc]]
            set len [::tcl::mathfunc::max {*}[lmap name [dict keys $d] {
                string length $name
            }]]
            dict for {name value} $d {
                lappend result [format {%*s  %s} $len [list $name] [list $value]]
            }
            return [list side {} [join $result \n]]
        } else {
            return [list side {} [set $desc]]
        }
    }

    method AddPrefix {prefix vals} {
        lmap val $vals {format {%s %s} $prefix $val}
    }

    method Info {key0 key} {
        info {*}[linsert $key0 1 $key]
    }

    method Methods {type desc} {
        set methods [info $type methods $desc -all]
        lmap method $methods {
            set call [info $type call $desc $method]
            lassign [lindex $call 0] calltype - class -
            # TODO I suppose calltype = 'filter' means that the next item should be examined?
            if {[string match ::oo::* $class]} {
                continue
            } else {
                if {$class eq "object"} {
                    set mtype [info object methodtype $desc $method]
                    lassign [info object definition $desc $method] args
                    set orig [list object $desc]
                } else {
                    set mtype [info class methodtype $class $method]
                    lassign [info class definition $class $method] args
                    set orig [list class $class]
                }
                list $mtype $method $args $orig
            }
        }
    }

}
