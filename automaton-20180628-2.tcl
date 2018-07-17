package require log

catch {State destroy}
oo::class create State {
    variable accept

    constructor args {
        proc [self namespace]::transition {symbol args} [format {
            oo::define %s method move->$symbol {} [list my Move $symbol {*}$args]
        } [self]]
        proc accept {} { set accept 1 }
    }

    # there will be one call to OnTransition for every symbol and target
    method OnTransition {symbol target trans} {
        set str "move [self object] ([namespace tail [info object class [self]]],$symbol) "
        append str "-> $target ([namespace tail [info object class $target]])"
        log::log d $str
        if {$trans ne {}} {
            # do transition action
        }
        return $target
    }

    # there will be one public move-> method for each symbol, with potentially
    # multiple targets
    method Move {symbol args} {
        return [lmap arg $args {
            lassign $arg state trans
            my OnTransition $symbol [$state new] $trans
        }]
    }

}

namespace eval foo {
    variable cls
    proc reset _cls {variable cls $_cls}
    proc transition {symbol args} {
        variable cls
        oo::define $cls method move->$symbol {} [list my Move $symbol {*}$args]
    }
    proc accept {} {
        variable cls
        oo::define $cls method accept {} {expr 1}
    }
}

catch {FSM destroy}
oo::class create FSM {
    variable paths

    constructor args {
        proc [self namespace]::state {name definition} {
            set state [::oo::class create ::$name]
            if no {
            oo::define $state constructor args {
                oo::objdefine [self] mixin ::State
                oo::objdefine [self] method accept {} {expr 0}
                #next {*}$args
            }
            }
            #error [namespace eval ::foo $definition]
            oo::define $state mixin ::State
            oo::define $state method accept {} {expr 0}
            ::foo::reset $state
            namespace eval ::foo $definition
            if no {
            oo::define $state [namespace eval ::foo $definition]
                namespace eval [info object namespace ::State] $definition
            }
            return $state
        }

        proc [self namespace]::start state {
            lappend paths [$state new]
        }

        my eval [lindex $args 0]
    }

}

FSM create M {
    state S0 {
        transition 0 S1
        transition 1 S0
        accept
    }
    state S1 {
        transition 0 S0
        transition 1 S1
    }
    start S0
}

return

FSM: create a machine instance
state (running in FSM): create a State class from which state instances can be created
transition: add a transition method to the State class being defined
accept: set the accept attribute of the State class to 1
