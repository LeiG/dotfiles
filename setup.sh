#!/bin/zsh

# NOTE: place current repo under ~/git/dotfiles

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

if [ -n "$ZSH_NAME" ]; then
    :
elif command -v chsh >/dev/null 2>&1; then
    chsh -s "$(which zsh)"
else
    echo 'Error: chsh is not installed.' >&2
    exit 1
fi

# link dotfiles
if [ -f ~/.tmux.conf ]; then
    mv ~/.tmux.conf ~/.tmux.conf.ex
fi
ln -s ~/git/dotfiles/tmux.conf ~/.tmux.conf

if [ -f ~/.vimrc ]; then
    mv ~/.vimrc ~/.vimrc.ex
fi
ln -s ~/git/dotfiles/vimrc ~/.vimrc

if [ -f ~/.zshrc ]; then
    mv ~/.zshrc ~/.zshrc.ex
fi
ln -s ~/git/dotfiles/zshrc ~/.zshrc

if [ -f ~/.aliases ]; then
    mv ~/.aliases ~/.aliases.ex
fi
ln -s ~/git/dotfiles/aliases ~/.aliases

if [ -f ~/.gitconfig ]; then
    mv ~/.gitconfig ~/.gitconfig.ex
fi
ln -s ~/git/dotfiles/gitconfig ~/.gitconfig

if [ -f ~/.gitignore ]; then
    mv ~/.gitignore ~/.gitignore.ex
fi
ln -s ~/git/dotfiles/gitignore ~/.gitignore
git config --global core.excludesfile ~/.gitignore

if [ -f ~/.yank.sh ]; then
    mv ~/.yank.sh ~/.yank.sh.ex
fi
ln -s ~/git/dotfiles/yank.sh ~/.yank.sh

# link claude code config
mkdir -p ~/.claude
for item in settings.json agents skills; do
    if [ -e ~/.claude/$item ]; then
        mv ~/.claude/$item ~/.claude/$item.ex
    fi
    ln -s ~/git/dotfiles/claude/$item ~/.claude/$item
done

# install pathogen.vim
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# install vim plugins
git clone https://github.com/tpope/vim-surround.git ~/.vim/bundle/vim-surround

# install color theme
mkdir -p ~/.vim/colors && \
curl -LSso ~/.vim/colors/zenburn.vim https://raw.githubusercontent.com/jnurmine/Zenburn/master/colors/zenburn.vim

echo
echo "Finishing setup and sourcing zshrc file..."
source ~/.zshrc
