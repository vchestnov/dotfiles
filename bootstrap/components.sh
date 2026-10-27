#!/usr/bin/env bash
set -Eeuo pipefail

# Each component is declared once. Order is also execution order.
# Put providers before consumers: Go before Git LFS/fzf, Julia/Vim/Node before
# LSP setup, msolve before FiniteFlow32, and Singular before polymake.
# --requires auto-selects a component; skipping that prerequisite is an error.
# Other build prerequisites may already be provisioned on the host.

register_component system-base \
    --installer install_system_base --file system.sh \
    --method 'apt/system' \
    --sudo true

register_component system-upgrade \
    --installer upgrade_system --file system.sh \
    --method 'apt/system' \
    --sudo true --risky true --requires system-base

register_component core \
    --installer install_core --file core.sh \
    --method 'configuration'

register_component zettelkasten \
    --installer install_zettelkasten --file core.sh \
    --method 'configuration' \
    --requires core

register_component reset-user-dirs \
    --installer reset_user_dirs --file core.sh \
    --method 'configuration' \
    --risky true --requires core

register_component remove-nautilus \
    --installer remove_nautilus --file system.sh \
    --method 'apt/system' \
    --sudo true --risky true

register_component fonts \
    --installer install_fonts --file fonts.sh \
    --method 'apt/system' \
    --sudo true

register_component desktop-tools \
    --installer install_desktop_tools --file desktop-tools.sh \
    --method 'apt/system' \
    --sudo true

register_component dwm \
    --installer install_suckless --file suckless.sh \
    --method 'pinned custom source + system integration' \
    --sudo true --plan print_suckless_plan

register_component go \
    --installer install_go_toolchain --file go.sh \
    --method 'pinned upstream tarball'

register_component git-lfs \
    --installer install_git_lfs --file git-lfs.sh \
    --method 'git source'

register_component rust-tools \
    --installer install_rust_tools --file rust.sh \
    --method 'rustup/cargo + git'

register_component tree-sitter \
    --installer install_tree_sitter --file rust.sh \
    --method 'cargo'

register_component zoxide \
    --installer install_zoxide --file cli-tools.sh \
    --method 'pinned source release'

register_component eza \
    --installer install_eza --file cli-tools.sh \
    --method 'pinned source release'

register_component dust \
    --installer install_dust --file cli-tools.sh \
    --method 'pinned source release'

register_component tlrc \
    --installer install_tlrc --file cli-tools.sh \
    --method 'pinned source release'

register_component duf \
    --installer install_duf --file cli-tools.sh \
    --method 'pinned source release' \
    --requires go

register_component procs \
    --installer install_procs --file cli-tools.sh \
    --method 'pinned source release'

register_component leaf \
    --installer install_leaf --file leaf.sh \
    --method 'pinned upstream binary'

register_component vim \
    --installer install_vim --file vim.sh \
    --method 'git source'

register_component neovim \
    --installer install_neovim --file neovim.sh \
    --method 'git source'

register_component node \
    --installer install_nvm_node_tools --file node.sh \
    --method 'nvm/npm'

register_component gmp \
    --installer install_gmp --file science.sh \
    --method 'pinned source release'

register_component ntl \
    --installer install_ntl --file science.sh \
    --method 'pinned source release'

register_component mpfr \
    --installer install_mpfr --file science.sh \
    --method 'pinned source release'

register_component flint \
    --installer install_flint --file science.sh \
    --method 'pinned source release'

register_component julia \
    --installer install_julia --file julia.sh \
    --method 'pinned upstream tarball'

register_component qd \
    --installer install_qd --file science.sh \
    --method 'tracked upstream source'

register_component finiteflow \
    --installer install_finiteflow --file science.sh \
    --method 'tracked upstream source'

register_component msolve \
    --installer install_msolve --file science.sh \
    --method 'tracked upstream source'

register_component finiteflow32 \
    --installer install_finiteflow32 --file science.sh \
    --method 'tracked upstream source'

register_component blade \
    --installer install_blade --file science.sh \
    --method 'tracked upstream source'

register_component gfan \
    --installer install_gfan --file science.sh \
    --method 'pinned source release'

register_component fermat \
    --installer install_fermat --file science.sh \
    --method 'pinned source release'

register_component science-extra \
    --installer install_science_extra --file science.sh \
    --method 'tracked upstream source'

register_component singular \
    --installer install_singular --file singular.sh \
    --method 'pinned source release'

register_component sage \
    --installer install_sage --file sage.sh \
    --method 'tracked upstream source'

register_component polymake \
    --installer install_polymake --file polymake.sh \
    --method 'tracked upstream source'

register_component openxm \
    --installer install_openxm --file openxm.sh \
    --method 'tracked upstream source'

register_component lsp \
    --installer install_lsp --file lsp.sh \
    --method 'local/upstream toolchains'

register_component email \
    --installer install_email --file email.sh \
    --method 'pinned source release'

register_component tex \
    --installer install_tex --file tex.sh \
    --method 'upstream installer' \
    --sudo true

register_component macaulay2 \
    --installer install_macaulay2 --file macaulay2.sh \
    --method 'apt/system' \
    --sudo true

register_component python-tools \
    --installer install_python_tools --file python-tools.sh \
    --method 'pipx'

register_component gpg \
    --installer install_gpg --file gpg.sh \
    --method 'apt + repository config' \
    --sudo true

register_component krita \
    --installer install_krita --file krita.sh \
    --method 'pinned AppImage' \
    --sudo true

register_component messengers \
    --installer install_messengers --file messengers.sh \
    --method 'apt/system' \
    --sudo true

register_component media \
    --installer install_media --file media.sh \
    --method 'apt/system' \
    --sudo true

register_group science 'gmp,ntl,mpfr,flint,julia,qd,finiteflow,finiteflow32,blade,gfan,fermat,msolve,science-extra'
register_group desktop-apps 'krita,messengers,media'
