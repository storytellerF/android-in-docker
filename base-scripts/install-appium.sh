#!/bin/bash
set -e

find_npm_bin() {
	local candidate_nvm_dir

	if command -v npm >/dev/null 2>&1; then
		command -v npm
		return 0
	fi

	for candidate_nvm_dir in "${NVM_DIR:-}" /usr/local/nvm "$HOME/.nvm"; do
		[ -n "$candidate_nvm_dir" ] || continue

		if [ -x "$candidate_nvm_dir/current/bin/npm" ]; then
			export NVM_DIR="$candidate_nvm_dir"
			export PATH="$candidate_nvm_dir/current/bin:$PATH"
			printf '%s\n' "$candidate_nvm_dir/current/bin/npm"
			return 0
		fi

		if [ -s "$candidate_nvm_dir/nvm.sh" ]; then
			export NVM_DIR="$candidate_nvm_dir"
			# shellcheck disable=SC1090
			. "$candidate_nvm_dir/nvm.sh"
			if command -v npm >/dev/null 2>&1; then
				command -v npm
				return 0
			fi
		fi
	done

	return 1
}

find_appium_bin() {
	local npm_bin_dir=$1

	if command -v appium >/dev/null 2>&1; then
		command -v appium
		return 0
	fi

	if [ -x "$npm_bin_dir/appium" ]; then
		export PATH="$npm_bin_dir:$PATH"
		printf '%s\n' "$npm_bin_dir/appium"
		return 0
	fi

	return 1
}

echo "Setting up Appium..."

NPM_BIN=$(find_npm_bin) || {
	echo "npm not found in PATH or common nvm locations." >&2
	exit 1
}
NPM_BIN_DIR=$(dirname "$NPM_BIN")
export PATH="$NPM_BIN_DIR:$PATH"

# Setup Appium，全局安装会安装到/usr/local/lib/node_modules，需要sudo权限
echo "Installing Appium..."
sudo "$NPM_BIN" install -g appium

APPIUM_BIN=$(find_appium_bin "$NPM_BIN_DIR") || {
	echo "appium binary not found after installation." >&2
	exit 1
}

# Setup appium driver and plugin，安装到~/.appium，不需要sudo权限
# npm_config_registry 从 ~/.npmrc 中读取，无需硬编码
echo "Installing Appium drivers and plugins..."
"$APPIUM_BIN" driver install uiautomator2
"$APPIUM_BIN" plugin install storage
"$APPIUM_BIN" plugin install inspector

echo "Appium setup completed successfully."
