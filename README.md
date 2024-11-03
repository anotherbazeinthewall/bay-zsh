# Bay-ZSH

Bay-ZSH is my personal `.zshrc` setup designed to simplify and centralize shell configurations across multiple machines, making my environment consistent, portable, and easy to update without the hassle of manual syncing. By tracking changes with Git, Bay-ZSH keeps configurations in sync, making updates straightforward to push, pull, and roll back as needed. With automated environment management, each machine is always ready to go, and if you're looking for a straightforward, Git-based way to manage your shell, Bay-ZSH might work well for you, too!

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/Bay-ZSH.git
   cd Bay-ZSH
   ```

2. **Run the Setup Script**:
   ```bash
   ./symlinker.sh
   ```
   This will back up your existing `~/.zshrc`, replace it with a symlink to Bay-ZSH, and reload your shell.

3. **Start Using Bay-ZSH**: Customize as needed within the repo, and your changes will apply globally.

## Usage

- **Make Changes**: Update `.zshrc` within the repo to add aliases, environment settings, or custom functions.
- **Track Updates**: Use Git to commit and push changes.
  ```bash
  git add .zshrc
  git commit -m "Updated configurations"
  git push origin main
  ```
- **Sync Across Devices**: Pull the latest changes on other machines and reload.
  ```bash
  git pull origin main
  source ~/.zshrc
  ```

## Contributing

This project is tailored for my own needs, but if you’d like to contribute or use it as a base for your own setup, go for it! Fork, customize, and share any improvements through a pull request if you’d like.

## License

Bay-ZSH is licensed under the MIT License. See the LICENSE file for details.
