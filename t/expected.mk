SHELL = /bin/sh
.SUFFIXES:

BREWFILE = brew/Brewfile
REQUIREMENTS = requirements.txt
XDG_CONFIG_HOME = $(HOME)/.config
# supported features:
# git_extras
# brew_install
# pip
# none
FEATURES = git_extras brew_install pip

# default: print help about targets
default:
	@grep -E '^# .+: .+' Makefile | tr -d '#' | tr ':' '\t'

# install: bootstrap the dotfiles
install: Makefile symlink $(FEATURES)

# update: update the dotfiles
update: Makefile pull_master update_submodules symlink brew_check vimtags pip

# vimtags: regenerate tags for vim helpfiles
vimtags:
	vim +':helptags ALL' +'q'

# brewfile: update the brewfile
brewfile:
	brew bundle dump --force --file="$(BREWFILE)"

# submodules: fixup any issues with submodules
submodules:
	git submodule sync
	git submodule update --init
	git clean -ffd links/vim/pack/

none:
	@:

USER_GITK = $(XDG_CONFIG_HOME)/git/gitk
DRACULA_GITK = Dracula/gitk/gitk

# git_extras: install git extras
git_extras: Makefile $(USER_GITK)

$(USER_GITK): Makefile $(DRACULA_GITK)
	[ -r "$?" ]
	mkdir -p "$$(dirname $@)"
	cp -iv -- "$?" "$@"

BREW_URL = https://raw.githubusercontent.com/Homebrew/install/master/install

# brew_install: install brew
brew_install:
	/usr/bin/ruby -e "$$( curl -fsSL $(BREW_URL) )"
	brew tap Homebrew/bundle
	brew bundle install --file="$(BREWFILE)"
	sudo sh -c "echo $$(brew --prefix)/bin/bash >> /etc/shells"
	chsh -s "$$(brew --prefix)/bin/bash" "$$USER"

# pip: install from requirements
pip: Makefile $(REQUIREMENTS)
	python3 -m pip install --user --requirement $(REQUIREMENTS)

pull_master:
	git checkout master
	git pull --recurse-submodules=on-demand origin master

update_submodules:
	git submodule sync
	git submodule update

# brew_check: check Brewfile with bundle
brew_check: Makefile $(BREWFILE)
	-brew bundle check --file="$(BREWFILE)"

LINKS = links/

SYMLINKS = \
$(HOME)/.ackrc \
$(HOME)/.bash \
$(HOME)/.bash_profile \
$(HOME)/.bashrc \
$(HOME)/.bin \
$(HOME)/.ctags.d \
$(HOME)/.git_template \
$(HOME)/.gitconfig \
$(HOME)/.gitignore_global \
$(HOME)/.gitshrc \
$(HOME)/.inputrc \
$(HOME)/.jupyter \
$(HOME)/.pythonrc \
$(HOME)/.tmplr \
$(HOME)/.tmux.conf \
$(HOME)/.vim \


$(HOME)/.ackrc: $(LINKS)ackrc
$(HOME)/.bash: $(LINKS)bash
$(HOME)/.bash_profile: $(LINKS)bash_profile
$(HOME)/.bashrc: $(LINKS)bashrc
$(HOME)/.bin: $(LINKS)bin
$(HOME)/.ctags.d: $(LINKS)ctags.d
$(HOME)/.git_template: $(LINKS)git_template
$(HOME)/.gitconfig: $(LINKS)gitconfig
$(HOME)/.gitignore_global: $(LINKS)gitignore_global
$(HOME)/.gitshrc: $(LINKS)gitshrc
$(HOME)/.inputrc: $(LINKS)inputrc
$(HOME)/.jupyter: $(LINKS)jupyter
$(HOME)/.pythonrc: $(LINKS)pythonrc
$(HOME)/.tmplr: $(LINKS)tmplr
$(HOME)/.tmux.conf: $(LINKS)tmux.conf
$(HOME)/.vim: $(LINKS)vim

# symlink: ensure symlinks created
symlink: Makefile $(SYMLINKS)

$(SYMLINKS):
	if test -e $@ || test -L $@ ; then rm -rf $@ ; fi
	ln -s $$(python -c "from os.path import *; print(relpath('$?', start=dirname('$@')))") $@
	@echo $@ '->' $$(python -c "from os.path import *; print(relpath('$?', start=dirname('$@')))")

Makefile: test.plink
	$$(python -c "from os.path import *; print(abspath('$?'))")
