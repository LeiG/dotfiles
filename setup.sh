#!/bin/bash

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# install pathogen.vim
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# link dotfiles
if [ -L ~/.tmux.conf ]; then
    mv ~/.tmux.conf ~/.tmux.conf.ex
fi
ln -s ~/git/dotfiles/tmux.conf ~/.tmux.conf

if [ -L ~/.vimrc ]; then
    mv ~/.vimrc ~/.vimrc.ex
fi
ln -s ~/git/dotfiles/vimrc ~/.vimrc

if [ -L ~/.zshrc ]; then
    mv ~/.zshrc ~/.zshrc.ex
fi
ln -s ~/git/dotfiles/zshrc ~/.zshrc
ln -s ~/git/dotfiles/aliases ~/.aliases

source ~/.zshrc
