The idea:
- chezmoi pulls and syncs dot files
- mise installs whatever global packages you need

notes on mac setup:
install [homebrew](https://brew.sh/)  
install [mise](https://mise.jdx.dev/getting-started.html) do not install using homebrew !!!  
brew install --cask iterm2  
brew install font-hack-nerd-font  
brew install pure  

THEN install [chezmoi](https://www.chezmoi.io/install/#one-line-package-install) (ordering is just a suggestion)

[read this stackoverflow to get quake console behavior](https://stackoverflow.com/questions/30850430/iterm2-hide-show-like-guake)  
remember to enable hack nerd font in iterm by going to settings > profile > text

if mise isn't installing everything you might have to manually run:  
$HOME/.local/bin/mise trust $HOME/.config/mise/config.toml && $HOME/.local/bin/mise install

also a note on .chezmoiexternals/mise.toml.tmpl:  
this is a very linux/devcontainer oriented dotfiles setup so the idea is that chezmoi will skip installing mise on mac. it does this by checking for a hostname on line 1 except hostnames are weird on mac
- typing 'hostname' in your terminal will append '.local' you dont want this
- chezmoi execute-template '{{ .chezmoi.hostname }}' -> appends '%' prompt character

heavily based on this [setup](https://www.skool.com/kubecraft/mise-devcontainers-dotfiles-a-developers-setup?p=8785e2d5)  
also found [here](https://github.com/mischavandenburg/dotfiles-rio)
