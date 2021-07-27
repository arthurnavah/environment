#!/bin/bash
mkdir logs &>/dev/null
now=$(date +"%F+%T")
log_file="$PWD/logs/install-$now.log"
sudo rm logs/install-* &>/dev/null

if [ ! -x "$0" ]; then
    echo "[Installer Error] : Execute permissions are required (+x)" | tee -a "$log_file"
    echo "exit 1" | tee -a "$log_file"
    exit 1
fi

main() {
    # check install all
    if [ "$install_all" == 1 ]; then
        install_editor=1
        install_console=1
    fi

    if [ "$install_editor" != 1 ] && [ "$install_console" != 1 ]; then
        echo "[Installer Error] : List of installations:" | tee -a "$log_file"
        echo -e "\tall" | tee -a "$log_file"
        echo -e "\teditor" | tee -a "$log_file"
        echo -e "\tconsole" | tee -a "$log_file"
        echo "exit 1" | tee -a "$log_file"
        exit 1
    fi

    requiredCommands git
    git pull origin master | tee -a "$log_file"

    # check requireds
    if [ "$install_editor" == 1 ]; then
        if [ "$no_providers" == 1 ]; then
            requiredCommands go node npm
        else
            requiredCommands go node npm python python2 python3
            requiredSudoCommands node npm
        fi

        requiredSudoCommands apt npm apt-key tee add-apt-repository

        #--- check node version
        nodeVersion="$(node --version | cut -d'.' -f1)"
        nodeVersion="${nodeVersion#'v'}"
        if [ "$nodeVersion" -lt 11 ]; then
            echo "[Editor Installer Error] : NodeJs version must be higher than v11.0.0 ( >= v12.0.0 )" | tee -a "$log_file"
            echo "exit 1" | tee -a "$log_file"
            exit 1
        fi

        #--- check go env
        if [ -z "$(go env GOROOT)" ]; then
            echo "[Editor Installer Error] : The GOROOT environment variable is not set" | tee -a "$log_file"
            echo "exit 1" | tee -a "$log_file"
            exit 1
        fi
        if [ -z "$(go env GOPATH)" ]; then
            echo "[Editor Installer Error] : The GOPATH environment variable is not set" | tee -a "$log_file"
            echo "exit 1" | tee -a "$log_file"
            exit 1
        fi

        #--- check .zshrc.arthurnavah
        principalContent=$(cat ~/.zshrc)
        if [[ "$principalContent" != "source ~/.zshrc.arthurnavah"* ]]; then
            echo "source ~/.zshrc.arthurnavah" >>~/.zshrc
        fi
    fi
    if [ "$install_console" == 1 ]; then
        requiredCommands curl wget git
        requiredSudoCommands snap apt
    fi

    echo ""
    echo "[Fonts Installer] : Installing fonts..." | tee -a "$log_file"
    sudo mkdir -p /usr/local/share/fonts/arthurnavah-fonts | tee -a "$log_file"
    sudo cp ./fonts/* /usr/local/share/fonts/arthurnavah-fonts/. | tee -a "$log_file"
    sudo fc-cache -f -v &>/dev/null | tee -a "$log_file"
    echo "[Fonts Installer] : ----------------------" | tee -a "$log_file"

    # installs
    if [ "$install_editor" == 1 ]; then
        if [ "$no_providers" == 1 ]; then
            echo "[Editor Installer] : Install Editor without Providers..." | tee -a "$log_file"
        else
            echo "[Editor Installer] : Install Editor..." | tee -a "$log_file"
        fi

        installEditor
    fi

    if [ "$install_console" == 1 ]; then
        echo "[Console Installer] : Install Console and Tools..." | tee -a "$log_file"

        installConsole
    fi
}

# get options
optstring=":n"
while getopts ${optstring} arg; do
    case ${arg} in
    n)
        no_providers=1
        ;;
    ?)
        echo "[Installer Error] : Invalid option:" | tee -a "$log_file"
        echo -e "\t$OPTARG" | tee -a "$log_file"
        echo "exit 1" | tee -a "$log_file"
        exit 1
        ;;
    esac
done
# excluding opts from the arguments
for a; do
    shift
    case $a in
    -*) opts+=("$a") ;;
    *) set -- "$@" "$a" ;;
    esac
done
# set vars with arguments
for p in "$@"; do
    eval install_"$p"=1
done
if [ "$#" == 0 ]; then
    install_editor=1
fi

# requiredCommands terminates the execution if there are no commands
requiredCommands() {
    concatMissingCommand=""
    for p in "$@"; do
        if ! p_tmp="$(type -p "$p")" || [[ -z $p_tmp ]]; then
            concatMissingCommand+="\t$p\n"
        fi
    done

    if [[ -n $concatMissingCommand ]]; then
        echo "[Installer Error] : Commands are required:" | tee -a "$log_file"
        echo -e "$concatMissingCommand" | tee -a "$log_file"
        echo "exit 1" | tee -a "$log_file"
        exit 1
    fi
}

# requiredSudoCommands terminates the execution if no 'sudo' commands exist
requiredSudoCommands() {
    concatMissingCommand=""
    for p in "$@"; do
        if ! p_tmp="$(sudo which "$p")" || [[ -z $p_tmp ]]; then
            concatMissingCommand+="\tsudo $p\n"
        fi
    done

    if [[ -n $concatMissingCommand ]]; then
        echo "[Installer Error] : Commands with SUDO are required:" | tee -a "$log_file"
        echo -e "$concatMissingCommand" | tee -a "$log_file"
        echo "exit 1" | tee -a "$log_file"
        exit 1
    fi
}

# installEditor install editor
installEditor() {
    echo "dark" >~/.mode | tee -a "$log_file"

    sudo apt install -y curl git xclip ripgrep silversearcher-ag | tee -a "$log_file"

    if [ "$no_providers" != 1 ]; then
        echo "" | tee -a "$log_file"
        echo "[Editor Installer] : Adding yarn key, Updating yarn..." | tee -a "$log_file"
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - &>/dev/null

        echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
        echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

        sudo apt update 1>/dev/null | tee -a "$log_file"
        sudo apt install -y python3-neovim python3-pip python3-dev python-setuptools python3-setuptools ruby-dev perl cpanminus yarn | tee -a "$log_file"
        echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

        requiredCommands pip pip3 gem
        requiredSudoCommands gem cpanm node npm
    fi

    requiredCommands curl git
    requiredSudoCommands apt

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : Removing current version of Vim and NeoVim..." | tee -a "$log_file"
    sudo apt remove -y --purge vim 2>/dev/null | tee -a "$log_file"
    sudo apt remove -y --purge vim-editor 2>/dev/null | tee -a "$log_file"
    sudo apt remove -y --purge neovim 2>/dev/null | tee -a "$log_file"
    sudo apt remove -y --purge nvim 2>/dev/null | tee -a "$log_file"
    sudo snap remove --purge vim-editor 2>/dev/null | tee -a "$log_file"
    sudo snap remove --purge vim 2>/dev/null | tee -a "$log_file"
    sudo snap remove --purge nvim 2>/dev/null | tee -a "$log_file"
    sudo snap remove --purge neovim 2>/dev/null | tee -a "$log_file"
    echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : Installing Vim and NeoVim..." | tee -a "$log_file"
    #sudo snap install vim-editor --beta | tee -a "$log_file"
    echo "[Editor Installer] : - Adding vim repository (ppa:jonathonf/vim)..." | tee -a "$log_file"
    sudo add-apt-repository -y ppa:jonathonf/vim
    sudo apt update
    sudo apt install -y vim
    #sudo snap install nvim --classic | tee -a "$log_file"
    sudo rm -r downloads/ 2>/dev/null | tee -a "$log_file"
    mkdir downloads/ | tee -a "$log_file"
    cd downloads/ || exit
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage | tee -a "$log_file"
    chmod u+x nvim.appimage | tee -a "$log_file"
    ./nvim.appimage --appimage-extract | tee -a "$log_file"
    ./squashfs-root/AppRun --version | tee -a "$log_file"
    sudo rm -r /nvim-arthurnavah/ | tee -a "$log_file"
    sudo rm /usr/bin/nvim | tee -a "$log_file"
    sudo mv squashfs-root /nvim-arthurnavah && sudo ln -s /nvim-arthurnavah/AppRun /usr/bin/nvim | tee -a "$log_file"
    cd ..
    echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

    requiredCommands nvim

    if [ "$no_providers" != 1 ]; then
        echo "" | tee -a "$log_file"
        echo "[Editor Installer] : Installing Providers for NeoVim..." | tee -a "$log_file"
        sudo npm install -g neovim | tee -a "$log_file"
        sudo gem install neovim | tee -a "$log_file"
        pip install -U pynvim | tee -a "$log_file"
        python2 -m pip install --user --upgrade pynvim | tee -a "$log_file"
        pip3 install -U pynvim | tee -a "$log_file"
        python3 -m pip install --user --upgrade pynvim | tee -a "$log_file"
        pip install -U msgpack-python | tee -a "$log_file"
        pip3 install -U msgpack-python | tee -a "$log_file"
        python3 -mpip install --user -U msgpack | tee -a "$log_file"
        yarn install --froken-lockfile | tee -a "$log_file"
        sudo npm install -g bash-language-server | tee -a "$log_file"
        echo "[Editor Installer] : ----------------------" | tee -a "$log_file"
    fi

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : Creating folders..." | tee -a "$log_file"
    mkdir ~/.vim 2>/dev/null | tee -a "$log_file"
    mkdir -p ~/.vim/tmp 2>/dev/null | tee -a "$log_file"
    sudo rm -r ~/.vim/bundles | tee -a "$log_file"
    mkdir -p ~/.vim/bundles 2>/dev/null | tee -a "$log_file"
    mkdir -p ~/.config/nvim 2>/dev/null | tee -a "$log_file"

    echo "[Editor Installer] : - Copying configuration VIM..." | tee -a "$log_file"
    cp ./config/vimrc ~/.vim/. | tee -a "$log_file"

    echo "[Editor Installer] : - Copying configuration NeoVim..." | tee -a "$log_file"
    cp ./config/init.vim ~/.config/nvim/. | tee -a "$log_file"

    echo "[Editor Installer] : - Copying configuration coc.nvim..." | tee -a "$log_file"
    cp ./config/coc-settings.json ~/.config/nvim/. | tee -a "$log_file"

    echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : Configuring tools GIT with Vim..." | tee -a "$log_file"
    git config --global core.editor nvim | tee -a "$log_file"
    git config --global diff.tool vimdiff | tee -a "$log_file"
    git config --global merge.tool vimdiff | tee -a "$log_file"
    echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : Install Vim Plugin Manager..." | tee -a "$log_file"
    curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh 2>/dev/null >~/.vim/bundles/installer.sh | tee -a "$log_file"
    sh ~/.vim/bundles/installer.sh ~/.vim/bundles | tee -a "$log_file"
    echo "[Editor Installer] : ----------------------" | tee -a "$log_file"

    nvim --headless +"call dein#clear_state()" +qall | tee -a "$log_file"
    nvim --headless +"call dein#recache_runtimepath()" +qall | tee -a "$log_file"
    nvim --headless +"call dein#install()" +qall | tee -a "$log_file"
    nvim --headless +"call dein#update()" +qall | tee -a "$log_file"
    nvim --headless +"call dein#remote_plugins()" +qall | tee -a "$log_file"
    nvim --headless +"call dein#save_state()" +qall | tee -a "$log_file"
    nvim --headless +UpdateRemotePlugins +qall | tee -a "$log_file"
    nvim --headless +GoInstallBinaries +qall | tee -a "$log_file"
    nvim --headless +GoUpdateBinaries +qall | tee -a "$log_file"
    nvim --headless +CocInstall +qall | tee -a "$log_file"
    nvim --headless +CocUpdate +qall | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Editor Installer] : + Installation Editor successful! +" | tee -a "$log_file"
}

# installConsole install console and tools
installConsole() {
    echo "dark" >~/.mode | tee -a "$log_file"

    sudo snap install alacritty --classic | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Installing tools..." | tee -a "$log_file"
    sudo apt install -y curl git tmux cmus zsh git-flow shellcheck exiftool rar fzf | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Adding yarn key, Updating yarn" | tee -a "$log_file"
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - &>/dev/null

    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

    sudo apt update 1>/dev/null | tee -a "$log_file"
    sudo apt install -y yarn 1>/dev/null | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Downloading Tmux Plugin Manager..." | tee -a "$log_file"
    sudo rm -r ~/.tmux/plugins | tee -a "$log_file"
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 1>/dev/null | tee -a "$log_file"

    echo "[Console Installer] : - Copying configuration Alacritty..." | tee -a "$log_file"
    mkdir -p ~/.config/alacritty 2>/dev/null | tee -a "$log_file"
    cp ./config/alacritty.yml ~/.config/alacritty/. | tee -a "$log_file"

    echo "[Console Installer] : - Copying configuration Tmux..." | tee -a "$log_file"
    cp ./config/.tmux.conf ~/. | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Installing Tmux Plugins..." | tee -a "$log_file"
    bash ~/.tmux/plugins/tpm/scripts/install_plugins.sh | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Installing Oh My ZSH!..." | tee -a "$log_file"
    curl -L http://install.ohmyz.sh 2>/dev/null | sh | tee -a "$log_file"
    wget --no-check-certificate http://install.ohmyz.sh -O - | sh | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"
    echo "[Console Installer] : Configuring Zsh Plugins..." | tee -a "$log_file"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/plugins/zsh-syntax-highlighting | tee -a "$log_file"
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/plugins/zsh-autosuggestions | tee -a "$log_file"

    echo "[Console Installer] : - Copying configuration Zsh..." | tee -a "$log_file"
    cp ./config/.zshrc ~/. | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : Configuring ZSH... enter your sudo or root password" | tee -a "$log_file"
    chsh -s "$(command -v zsh)" | tee -a "$log_file"
    echo "[Console Installer] : ----------------------" | tee -a "$log_file"

    echo "" | tee -a "$log_file"
    echo "[Console Installer] : + Installation Console successful! (Restarting the computer to use Zsh for the first time) +" | tee -a "$log_file"
}

main "$@"
