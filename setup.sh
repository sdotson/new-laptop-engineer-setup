#!/bin/bash

# feel free to update this to whatever directory you want to use in ~/ to store github repos
github_repo_directory="github_repos"

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\\n" "$text" >> "$zshrc"
    else
      printf "\\n%s\\n" "$text" >> "$zshrc"
    fi
  fi
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

# shellcheck disable=SC2016
append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

# Determine Homebrew prefix
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

update_shell() {
  local shell_path;
  shell_path="$(command -v zsh)"

  echo "Changing your shell to zsh ..."
  if ! grep "$shell_path" /etc/shells > /dev/null 2>&1 ; then
    echo "Adding '$shell_path' to /etc/shells"
    sudo sh -c "echo $shell_path >> /etc/shells"
  fi
  sudo chsh -s "$shell_path" "$USER"
}

case "$SHELL" in
  */zsh)
    if [ "$(command -v zsh)" != "$HOMEBREW_PREFIX/bin/zsh" ] ; then
      update_shell
    fi
    ;;
  *)
    update_shell
    ;;
esac

if ! command -v brew >/dev/null; then
  echo "Installing Homebrew ..."
    /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    append_to_zshrc "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""

    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi

# fix homebrew path warning
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "$HOME/.zprofile" 
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Updating Homebrew formulae ..."
brew update

# no need to install git, it's already installed on modern macOS. but we do need to accept the license
echo "Don't panic. A window is going to appear to install xcode developer tools, which is a dependency for git"
xcode-select --install || true

brew install openssl
brew install iterm2
brew install zsh
brew install teleport-connect

# install code editor
brew install --cask visual-studio-code
brew install --cask postico

echo "Now we're going to generate a new SSH key."
read -p 'Paste your email address here:' email
# generate and require a passphrase
ssh-keygen -t ed25519 -C $email
# add key to OS X keychain to not have to enter passphrase
echo 'Host *\n\tUseKeychain yes\n\tAddKeysToAgent yes\n' >> ~/.ssh/config
# copy the public key to your clipboard
cat ~/.ssh/id_ed25519.pub | pbcopy
echo "You now have the new SSH key copied to your clipboard. Add them to Github in the window that opens up"
cat ~/.ssh/id_ed25519.pub

# add the key to github (it's in your clipboard)
open https://github.com/settings/ssh/new

echo 'Press any key and hit enter when you are ready to proceed'
read -rsn1 anykey

# GitHub CLI
brew install gh

echo "Now generate a new NPM account for your email if neccessary and a new Read-Only Classic access token."
open "https://www.npmjs.com/"
read -p 'Paste your new NPM access token here:' npmtoken

echo "Sweet. Now we're going to update your ~/.npmrc with that value"
echo '//registry.npmjs.org/:_authToken='"$npmtoken" >> ~/.npmrc
echo "All Done. Hurray!"
