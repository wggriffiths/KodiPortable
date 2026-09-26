# First-launch add-on bootstrap

`service.tinkerer.bootstrap` is a temporary Kodi service used by
`Install.bat` after it directly extracts the private Fen Light and
CocoScrapers packages into a fresh portable profile.

Kodi's normal add-on installer enables an add-on as part of installation, but
direct folder extraction registers new add-ons as disabled. The helper uses
Kodi's internal add-on API to enable the private add-ons and their dependencies
on the first launch. It then removes its temporary manifest entry, disables
itself, and deletes its files.

The helper is run by Kodi's bundled Python 3 runtime. It does not require a
separate Windows Python installation.
