# The idea:
- chezmoi pulls and syncs dot files
- mise installs whatever global packages you need

## notes on mac setup:
install [homebrew](https://brew.sh/)  
install [mise](https://mise.jdx.dev/getting-started.html) do not install using homebrew !!!  
brew install --cask iterm2  
brew install font-hack-nerd-font  
brew install --cask arc  
brew install pure  
brew install scroll-reverser  
brew install --cask visual-studio-code  
brew install --cask raycast  
brew install --cask zed  
brew install --cask devpod  
brew install --cask gamemaker  
brew install --cask blender  
brew install --cask tiled  
brew install --cask beeper  
brew install --cask openemu  
brew install --cask nuage  
brew install nicotine-plus  
brew install --cask steam  
brew install --cask itch  
brew install --cask heroic  
brew install --cask battle-net  
brew install --cask discord  
brew install --cask 8bitdo-ultimate-software  
brew install --cask obsidian  
brew install --cask logitech-g-hub  
brew install --cask raindropio  
brew install --cask plex  
brew install --cask iina  
brew install --cask arc  
brew install --cask orion  
brew install --cask ableton-live-suite  
brew install --cask arturia-software-center  
brew install --cask fightcade  
brew install --cask transmission  
brew install --cask slippi-dolphin  
brew install --cask jdownloader  
brew install --cask macsyzones  
brew install --cask alt-tab  
brew install flashspace  
### kubernetes tools 
brew install --cask rancher  
brew install docker-credential-helper


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
also found [here](https://github.com/rio/dotfiles)
also see: https://www.skool.com/kubecraft/classroom/1c6ab39e?md=a018c921401b4e0394d0971752ec43f8

TODO:  
- figure out windows configuration management (glazewm yasb package manager)  
- maybe try out a different window management / hotkey solution for mac  
- backup raycast configuration even if it is encrypted  
- go through twitter bookmarks and youtube watch later for processing in obsidian  
- setup retroNAS and gamevault  
- cleanup steam and playnite installation on desktop pc  
- organize obsidian vault  
