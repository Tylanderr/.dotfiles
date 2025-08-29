# TODO
Ansible playbook for setup
# Environment Setup
## Fix hostname if necessary
Edit /etc/wsl.conf
```
[network]
hostname = tjh
generateHosts = false
```
- Edit /etc/hosts
- Edit /etc/hostname
## First Run
```
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install ca-certificates
```
## Install CLI Tools and build dependencies
```
sudo apt install stow
sudo apt install unzip
sudo apt-get install ripgrep
sudo apt-get install tree
sudo apt install fd-find
sudo apt install ansible -y
sudo apt install python3
sudo apt install gcc
```
## Dotfiles
```
cd ~ && git clone git@github.com:Tylander732/.dotfiles.git
cd .dotfiles/
stow .
```
## Install nvm, npm
- Install nvm
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.bashrc
```
- nvm list-remote
- nvm install version-number
- Create symlinks to the node things that nvm installed (if necessary)
```
sudo ln -s $(realpath `which npm`) /usr/local/bin/npm
sudo ln -s `which node` /usr/local/bin/node
sudo ln -s `which tsc` /usr/local/bin/tsc
```
## Install Homebrew
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
## Install sshs
```
brew install sshs
```
## Download neovim tarball
- Move it to ~/.local/bin
```
tar -xzvf nvim-linux-x86_64.tar.gz
ln -s ./nvim-linux-x86_64/bin/nvim ./nvim
```
## FZF
```
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```
## Tmux
```
sudo apt install tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```
- Place tmux.conf in .config/tmux/
    - prefix+I to install
## Install Starship
```
curl -sS https://starship.rs/install.sh | sh
```
## Install Lazygit
```
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
```
## Install EZA
```
sudo apt update
sudo apt install -y gpg
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza
```
## Install GO
- Download tarball and move it to home
```
cd /mnt/c/Users/hardi/Downloads/
```
- Delete old installation of go
```
sudo rm -rf /usr/local/go 
```
- Extract tarball to home
```
tar -xzf go1.xx.x.linux-amd64.tar.gz
```
- Move to /usr/local/
```
mv go /usr/local/
```
## Install Java
```
sudo apt install openjdk-17-jdk openjdk-17-jre
sudo apt install maven -y
```
