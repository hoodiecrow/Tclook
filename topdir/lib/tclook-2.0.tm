
namespace eval tclook {
    namespace export tclook
    variable view {}
}

# TclOO-based object/class/namespace browser

# View is not a megawidget. Currently, if the instance is destroyed, it closes
# its window. If the window is closed, the instance remains. If the window is
# closed and 'tclook' is called again, a new instance is created.

proc ::tclook::tclook args {
    # Ensure that a 'view' exists as a namespace variable.
    # Check if the asked-for item is already showing. If so, make it visible,
    # otherwise add it to the view.
    variable view
    if no {
        if {$view eq {} || ![$view hasWindow]} {
            set view [View new .tclook]
            $view bind <<TreeviewSelect>> {::tclook::TreeviewSelect %W}
        }
    } else {
        if {$view eq {}} {
            set view [Print new]
        }
    }
    set key [MakeKey [uplevel 1 {namespace current}] {*}$args]
    if {[$view exists $key]} {
        $view see $key
    } else {
        $view insert {*}[Values {*}$key] 
    }
}

proc ::tclook::ResolveNamespace {ns desc} {
    set _desc [namespace eval $ns [list namespace which $desc]]
    if {$_desc ne {}} {
        return $_desc
    } else {
        return $desc
    }
}

proc ::tclook::MakeKey {ns args} {
    # Create an identifier for an item to be viewed, consisting of a viewing
    # category (object, class, namespace) and a qualified command name.
    switch [llength $args] {
        0 {
            return {class ::oo::class}
        }
        1 {
            # A single argument must be the name of an object, class, a namespace, or a Tcl command procedure.
            # The slightly cumbersome test for a proc (instead of just [llength [info procs $desc]] > 0) is to handle proc names that are glob patterns
            set desc [ResolveNamespace $ns [lindex $args 0]]
            if {[info object isa class $desc]} {
                return [list class $desc]
            } elseif {[info object isa object $desc]} {
                return [list object $desc]
            } elseif {[namespace exists $desc]} {
                return [list namespace $desc]
            } elseif {$desc in [info procs [namespace qualifiers $desc]::*]} {
                return [list command $desc]
            }
        }
        default {
            set desc [ResolveNamespace $ns [lassign $args type]]
            return [list $type $desc]
        }
    }
    return -code error [format {unknown key arguments "%s"} $args]
}

catch { ::tclook::Print destroy }
oo::class create ::tclook::Print {

    method exists key { expr 0 }

    method insert {destination key0 values} {
        switch $destination {
            code {
                puts $values
            }
            view {
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

proc ::tclook::TreeviewSelect w {
    # Handler for <<TreeviewSelect>> events. If the clicked-on item is a leaf
    # item, use the 'tclook' command with its text as argument list to add it to
    # the view.
    set item [$w focus]
    if {[$w tag has leaf $item]} {
        ::tclook::tclook {*}[$w item $item -text]
    }
}

catch { ::tclook::View destroy }
oo::class create ::tclook::View {
    variable view code bigfont

    constructor args {
        package require Tk
        lassign $args top
        if {$top eq {}} {
            set top .tclook
        }
        destroy $top
        toplevel $top
        set view [ttk::treeview $top.view -show tree -yscroll [list $top.vs set]]
        set vs [ttk::scrollbar $top.vs -orient vertical -command [list $view yview]]
        grid $view $vs -sticky news
        set code [text $top.code -height 9 -width 30 -yscroll [list $top.cs set]]
        set cs [ttk::scrollbar $top.cs -orient vertical -command [list $code yview]]
        grid $code $cs -sticky news
        grid columnconfigure $top $view -weight 1
        grid rowconfigure $top $view -weight 1
        grid rowconfigure $top $code -weight 1
        set bigfont [my MakeFont TkDefaultFont -weight bold -size 10]
        $view tag configure big -font $bigfont
        oo::objdefine [self] forward exists $view exists
    }

    destructor {
        font delete $bigfont
        catch { destroy [winfo parent $view] }
    }

    method MakeFont {name args} {
        # Create a new font based on a named font with the rest of the
        # arguments being font options.
        set font [font create]
        font configure $font {*}[dict merge [font actual $name] $args]
        return $font
    }

    method bind args {
        bind $view {*}$args
    }

    method see key {
        $view see $key
        $view item $key -open true
    }

    method code text {
        $code delete 1.0 end
        $code insert end $text
    }

    method Insert0 key0 {
        $view insert {} end -id $key0 -text $key0 -tags big
    }

    method Insert1 {key0 key1} {
        $view insert $key0 end -id [list $key0 $key1] -text [string totitle $key1]
    }

    method Insert2 {key0 key1 item} {
        $view insert [list $key0 $key1] end -text $item -tags leaf
    }

    method insert {destination key0 values} {
        # Insert a whole item as a three-level dictionary (with a single member
        # in the outermost level) into the view, unless the Values lookup
        # results in an empty key, in which case the text in 'values' is
        # inserted into the 'code' field.
        switch $destination {
            code {
                my code $values
            }
            view {
                my Insert0 $key0
                dict for {key1 items} $values {
                    my Insert1 $key0 $key1
                    foreach item $items {
                        my Insert2 $key0 $key1 $item
                    }
                }
                my see $key0
            }
            none { ; }
        }
    }

    method hasWindow {} {
        winfo exists $view
    }

}

catch { ::tclook::Values destroy }
oo::object create ::tclook::Values
oo::objdefine ::tclook::Values {

    method object desc {
        set q [list [self method] $desc]
        dict set values methods [my Methods {*}$q]
        set key namespace
        dict set values $key [my AddPrefix $key [my Info $q $key]]
        foreach key {class mixins} {
            dict set values $key [my AddPrefix class [my Info $q $key]]
        }
        return [list view $q $values]
    }

    method class desc {
        set type [self method]
        set q [list $type $desc]
        dict set values methods [my Methods {*}$q]
        foreach key {superclasses subclasses mixins} {
            dict set values $key [my AddPrefix $type [my Info $q $key]]
        }
        set key instances
        if {[info object isa metaclass $desc]} {
            dict set values $key [my AddPrefix class [my Info $q $key]]
        } else {
            dict set values $key [my AddPrefix object [my Info $q $key]]
        }
        return [list view $q $values]
    }

    method namespace desc {
        set type [self method]
        dict set values vars [my AddPrefix var [info vars $desc\::*]]
        dict set values commands [my AddPrefix command [info commands $desc\::*]]
        dict set values children [my AddPrefix $type [namespace children $desc]]
        return [list view [list $type $desc] $values]
    }

    method method desc {
        lassign $desc name - orig
        lassign $orig type defi
        return [list code {} [list method $name {*}[info $type definition $defi $name]]]
    }

    method command desc {
        try {
            list proc $desc [info args $desc] [info body $desc]
        } on ok values {
            return [list code {} $values]
        } on error {} {
            return [list code {} {}]
        }
    }

    method var desc { return [list none {} {}] }

    method AddPrefix {prefix vals} {
        lmap val $vals {format {%s %s} $prefix $val}
    }

    method Info {q key} {
        info {*}[linsert $q 1 $key]
    }

    method Methods {type desc} {
        set result {}
        set methods [info $type methods $desc -all]
        foreach method $methods {
            set call [info $type call $desc $method]
            lassign [lindex $call 0] calltype - class -
            # TODO I suppose calltype = 'filter' means that the next item should be examined?
            if {![string match ::oo::* $class]} {
                if {$class eq "object"} {
                    set mtype [info object methodtype $desc $method]
                    lassign [info object definition $desc $method] args
                    set orig [list object $desc]
                } else {
                    set mtype [info class methodtype $class $method]
                    lassign [info class definition $class $method] args
                    set orig [list class $class]
                }
                lappend result [list $mtype $method $args $orig]
            }
        }
        return $result
    }

}

if {![info exists TCLOOK] || !$TCLOOK} {
    set TCLOOK 1
    package require log
    cd ~/code/Tclook/
    tcl::tm::path add topdir/lib/
    ::log::lvSuppressLE i 0
    catch { package forget tclook } ; package require tclook
    source -encoding utf-8 automaton-20180628-2.tcl
    oo::class create Foo {method foo {a b} {list $b $a}}
    oo::class create Bar {superclass Foo ; method Qux {} {my foo m n} ; method quux {} {my foo x y}}
    Foo create foo
    Bar create bar
    ::tclook::tclook
}
