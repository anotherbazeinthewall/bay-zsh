# Bay-ZSH

I started messing with my `.zshrc` as an exercise in shell scripting: what better way to get more comfortable in the terminal than customizing my shell experience and having to deal with all of the bugs that come along with it? I created this repo to track my progress and facilitate utilization across my multiple machines. And who knows??? Maybe someone else will find it useful too!

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

This project is tailored for my own needs and fixations, but if you’d like to contribute or use it as a base for your own setup, go for it! Fork, customize, and share any improvements through a pull request if you’d like :) 
