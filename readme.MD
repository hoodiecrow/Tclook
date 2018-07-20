
# Tclook

## TclOO-based object/class/namespace browser

Display introspection info about a "thing", which can be a

* TclOO class
* TclOO object
* namespace
* TclOO method
* Tcl command procedure

Provides one command, `tclook`, and two classes, `PrintView` and `TreeView`. The `*View` classes show the information in some specific way. `PrintView` prints the information to `stdout`, and `TreeView` shows it in a `ttk::treeview` window (with a `text` side display for method/command info).

The information shown is a snapshot of the contents of the thing. Changes to the thing will not be reflected in a `TreeView` (but clicking on a thing key will reload the thing).

Install for use by copying this file

https://github.com/hoodiecrow/Tclook/blob/master/topdir/lib/tclook-2.0.tm

put it somewhere where on the `tm` path and use `package require tclook`.

### Invocation

The `tclook` command can be invoked with several argument sets.

* without arguments, it fetches info about the class `::oo::class`.
* with a single argument, the name of a TclOO class, TclOO object, namespace, or a Tcl command procedure, it fetches info about it (guessing what type of thing it is).
* with a keyword argument (`class`, `object`, `namespace`, `method`, `command`, or `set`), it acts as follows:
    * for `class`|`object`|`namespace`|`command` *name*: fetch info on the name with the assumption that it has the given type
    * for `method` *name* *arglist* *source*: fetch and display info about a method defined in *source*, which is a list of either `object` or `class` and the name of that object or class. The *arglist* argument is ignored but must be present.
    * for `set`: fetch and display the contents of a variable or array.

The command attempts to construct a qualified name from the name given.

### Introspection

The information gathered about the thing depends on what the thing is:

 * **class**: ("public") methods, superclasses, subclasses, mixins, instances
 * **object**: ("public") methods, namespace, class, mixins
 * **namespace**: vars, commands, children
 * **method**: type (method or forward), name, argument list, body
 * **command**: name, argument list, body
 * **set**: the value of a variable, or a `dict`-style table of values for an array

### \*view interface

Anything can be a view if it can be called with the keywords/subcommands/methods `exists`, `display`, `insert`, and `replace`. All these methods accept a single key argument naming the thing to be displayed (a list of `class`|`object`|`namespace` *name*).

For the `PrintView` class, `exists` always returns 0, and the other methods all print the thing's info to `stdout`. 

For the `TreeView` class, thing snapshots of type class, object, or namespace are stored as subtrees in the view tree. The `exists` method tells if the thing is already displayed in the view, `display` makes the thing visible in the view (scrolling the display to it), `insert` adds a snapshot of the thing to the view, and `replace` reloads the display of the thing to show a new snapshot of it in the same place. For method and command things, `insert` just shows the fetched info without storing it. Clicking on any leaf in the tree inserts the thing named by it, and clicking on a thing key reloads the thing.

If no view exists when `tclook` is first called, a PrintView view is created. To replace the default view, set `::tclook::view` to a view instance.

### Error handling

Minimal. An error is raised if the command can't figure out its arguments. It is assumed that this tool will be able to fail without messing up anything important. Resource management is also minimal: destroying a view also destroys the view's Tk resources, but closing a window leaves the view instance behind.

### Bugs and fixes

 * **2018-07-20:** Can now fetch information (such as there is) for `forward` methods.

 * **2018-07-20:** Distinguish between class and object for defining name from `info c|o call \<...\>`.

 * **2018-07-20:** Look past filters in the call chain.

