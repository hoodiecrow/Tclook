
namespace eval tclook {
    namespace export tclook
    variable view {}
}

# TclOO-based object/class/namespace browser

# Anything can be a view if it responds to the methods 'exists {key}', 'display
# {key}', and 'insert {destination key0 values}', OR has a 'exists' method that
# always returns false, in which case only the 'insert' method needs to be
# working. See docs for the Print class.

# If no view exists, a Print view is created which outputs all info to stdout.
# A View class which places the info in a ttk::treeview is included in the
# package. To use that instead, set ::tclook::view to an instance of that
# class.

proc ::tclook::tclook args {
    # Ensure that a 'view' exists as a namespace variable.
    # Check if the asked-for item is already showing. If so, make it visible,
    # otherwise add it to the view.
    variable view
    if {$view eq {}} { set view [Print new] }
    set key [MakeKey [uplevel 1 {namespace current}] {*}$args]
    if {[$view exists $key]} {
        $view display $key
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
            # A single argument must be the name of an object, class, a
            # namespace, or a Tcl command procedure.
            # The slightly cumbersome test for a proc (instead of just [llength
            # [info procs $desc]] > 0) is to handle proc names that are glob
            # patterns.
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
            # 'desc' here might not be a command name at all, but the
            # ResolveNamespace command will just pass the original string back
            # in that case.
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

catch { ::tclook::View destroy }
oo::class create ::tclook::View {
    variable main side bigfont

    constructor {{top .tclook}} {
        package require Tk
        destroy $top
        toplevel $top
        set main [ttk::treeview $top.main -show tree -yscroll [list $top.vs set]]
        set vs [ttk::scrollbar $top.vs -orient vertical -command [list $main yview]]
        grid $main $vs -sticky news
        set side [text $top.side -height 9 -width 30 -yscroll [list $top.cs set]]
        set cs [ttk::scrollbar $top.cs -orient vertical -command [list $side yview]]
        grid $side $cs -sticky news
        grid columnconfigure $top $main -weight 1
        grid rowconfigure $top $main -weight 1
        grid rowconfigure $top $side -weight 1
        set bigfont [my MakeFont TkDefaultFont -weight bold -size 10]
        $main tag configure big -font $bigfont
        oo::objdefine [self] forward exists $main exists
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
        }
    }

    method MakeFont {name args} {
        # Create a new font based on a named font with the rest of the
        # arguments being font options.
        set font [font create]
        font configure $font {*}[dict merge [font actual $name] $args]
        return $font
    }

    method Insert0 key0 {
        $main insert {} end -id $key0 -text $key0 -tags big
    }

    method Insert1 {key0 key1} {
        $main insert $key0 end -id [list $key0 $key1] -text [string totitle $key1]
    }

    method Insert2 {key0 key1 item} {
        $main insert [list $key0 $key1] end -text $item -tags leaf
    }

    method insert {destination key0 values} {
        # Insert a whole item as a three-level dictionary (with a single member
        # in the outermost level) into the view, unless the Values lookup
        # results in an empty key, in which case the text in 'values' is
        # inserted into the 'side' field.
        switch $destination {
            side {
                $side delete 1.0 end
                $side insert end $values
            }
            main {
                my Insert0 $key0
                dict for {key1 items} $values {
                    my Insert1 $key0 $key1
                    foreach item $items {
                        my Insert2 $key0 $key1 $item
                    }
                }
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
        dict set values vars [my AddPrefix var [info vars $desc\::*]]
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

    method var desc { return [list none {} {}] }

    method AddPrefix {prefix vals} {
        lmap val $vals {format {%s %s} $prefix $val}
    }

    method Info {key0 key} {
        info {*}[linsert $key0 1 $key]
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
