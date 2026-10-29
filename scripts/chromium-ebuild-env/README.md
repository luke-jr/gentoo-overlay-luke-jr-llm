# Checking that an eclass change leaves the existing ebuilds alone

`eclass/chromium-llm.eclass` is shared by every `www-client/chromium` ebuild in the tree, the
older versions too. A change made for a new version must not change what the existing ebuilds do
(see the eclass's description). These scripts check that:

1. Before the change: `snapshot.sh BEFORE` (as root, in a system with this repository and the
   build dependencies). For each ebuild, it saves the metadata (dependencies, `IUSE`, `SRC_URI`,
   ...) and the environment after `pkg_setup`: every function and variable, eclasses' included.
2. After the change: `snapshot.sh AFTER`.
3. `compare.py BEFORE AFTER` lists the differences, per ebuild. For an ebuild the change isn't
   meant for, there must be none. For one it is meant for, read each.

Taking a snapshot twice in a row gives no differences, so any difference comes from the change.
Dependency-style variables are compared as sets of their top-level entries, as an eclass may
change their order. A phase function that became an `EXPORT_FUNCTIONS` wrapper is compared with
the function it calls.

This compares the code, not what it does with each USE flag: a difference in a function needs
reading, and a build where it matters.
