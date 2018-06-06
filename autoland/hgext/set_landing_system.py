# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from mercurial import commands, encoding, extensions

testedwith = "4.5"

EXTRA_KEY = "moz-landing-system"


def commitcommand(orig, ui, repo, *args, **kwargs):
    repo.moz_landing_system = kwargs.get("landing_system")
    return orig(ui, repo, *args, **kwargs)


def reposetup(ui, repo):
    if not repo.local():
        return

    class MozLandingRepo(repo.__class__):
        def commit(self, *args, **kwargs):
            if hasattr(self, "moz_landing_system"):
                kwargs.setdefault("extra", {})
                kwargs["extra"][EXTRA_KEY] = encoding.tolocal(self.moz_landing_system)
            return super(MozLandingRepo, self).commit(*args, **kwargs)

    repo.__class__ = MozLandingRepo


def extsetup(ui):
    entry = extensions.wrapcommand(commands.table, "commit", commitcommand)
    options = entry[1]
    options.append(("", "landing_system", "", "set commit's landing-system identifier"))
