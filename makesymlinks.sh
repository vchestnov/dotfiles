#!/bin/bash
############################
# .make.sh
# This script creates symlinks from the home directory to any desired dotfiles in ~/dotfiles
############################

########## Variables

dir=~/dotfiles                    # dotfiles directory
private_dir=~/dotfiles/private    # private dotfiles directory
olddir=~/.config/dotfiles_old     # old dotfiles backup directory
#files="bashrc vimrc vim zshrc oh-my-zsh private scrotwm.conf Xresources"    # list of files/folders to symlink in homedir
if [[ "$(uname)" == "Darwin" ]]; then
    # list of dotfiles in ~/dotfiles/
   files="vimrc vim gitignore_global gitconfig zshrc tmux.conf fzf.zsh"

    # private dotfiles in ~/dotfiles/private
    private_files=""
else
    # list of dotfiles in ~/dotfiles/
    files="vimrc vim gitignore_global gitconfig xinitrc xsession Xresources bashrc zshrc tmux.conf fzf.bash"

    # private dotfiles in ~/dotfiles/private
    private_files="bash_history"
fi

##########

# create backup directory for old dotfiles
echo -n "Creating $olddir for backup of any existing dotfiles in home ..."
mkdir -p $olddir
echo "done"

# change to the dotfiles directory
echo -n "Changing to the $dir directory ..."
cd $dir || { echo "Failed to change directory to $dir"; exit 1; }
echo "done"

# process public dotfiles
for file in $files; do
    echo "Moving any existing dotfiles from home to $olddir"
    mv -f ~/.$file "$olddir/"
    echo "Creating symlink to $file in home directory"
    ln -s "$dir/$file" ~/.$file
done

# process private dotfiles
for file in $private_files; do
    echo "Moving any existing dotfiles from home to $olddir"
    mkdir -p "$olddir/private/$(dirname $file)"
    mv -f ~/.$file "$olddir/private/$file"
    echo "Creating symlink to $file in home directory"
    ln -s "$private_dir/$file" ~/.$file
done

echo "Dotfiles setup complete. Auf Wiedersehen!"

# install_zsh () {
# # Test to see if zshell is installed.  If it is:
# if [ -f /bin/zsh -o -f /usr/bin/zsh ]; then
#     # Clone my oh-my-zsh repository from GitHub only if it isn't already present
#     if [[ ! -d $dir/oh-my-zsh/ ]]; then
#         git clone http://github.com/robbyrussell/oh-my-zsh.git
#     fi
#     # Set the default shell to zsh if it isn't currently set to zsh
#     if [[ ! $(echo $SHELL) == $(which zsh) ]]; then
#         chsh -s $(which zsh)
#     fi
# else
#     # If zsh isn't installed, get the platform of the current machine
#     platform=$(uname);
#     # If the platform is Linux, try an apt-get to install zsh and then recurse
#     if [[ $platform == 'Linux' ]]; then
#         if [[ -f /etc/redhat-release ]]; then
#             sudo yum install zsh
#             install_zsh
#         fi
#         if [[ -f /etc/debian_version ]]; then
#             sudo apt-get install zsh
#             install_zsh
#         fi
#     # If the platform is OS X, tell the user to install zsh :)
#     elif [[ $platform == 'Darwin' ]]; then
#         echo "Please install zsh, then re-run this script!"
#         exit
#     fi
# fi
# }
#
#install_zsh
