# Design for Enterprise Config for Git

## Features
Some of these features are already implemented:

### Installation:
#### Required Features:
- Install Git Enterprise Config for Git
- Install Git depending on OS
- Install Git LFS
- Install SourceTree
- Install SmartGit
- Generate new SSH key
- Setup SSH agent depending on OS
- Setup credential manager
  (for Windows maybe https://github.com/Microsoft/Git-Credential-Manager-for-Windows
  should be use, to be checked if this makes proxy handling easier)
- Setup proxy
- Publish new SSH public key on GitHub (also on training server?)
- Generate personal access token on GitHub
- Configure user name and e-mail based on GitHub account data

#### Implemented:
- Install Git Enterprise Config for Git
  - `install.bat` (Windows only): Asks for user name and password and then downloads
    `install-helper.ps1`, inside replaces user name and password and executes it
  - `install.sh` (Linux/OSx only): Clones Git Enterprise Config for Git and configures
    global Git config file to include `config.include`
- Install Git depending on OS
  - `install-helper.ps1` (Windows only): Powershell script which downloads the Git for
    Windows installer and executes it in silent mode. Aftewards it clones Git
    Enterprise Config for Git and configures global Git config file to include
    `config.include`
  - Linux/OSx: Git already exists, so that clone should work
- `setup.sh`: Contains sevaral steps (needs to be splitted)
  - Get GitHub user name and password
  - Creates a GitHub personal access token if it does not exist
  - Updates Enterprise Config for Git if necessary
  - Check Git version
  - Updates/installs Git LFS depending on OS
  - Configures URL rewrites, so avoid problems with SSH style URLs
    **=> to be checked if this is desired for all**
  - Configures user name and e-mail in global Git config file based on GitHub account
  - Configures bugtraq regex for JIRA used by SmartGit (SourceTree currently does not
    respect this)
  - Checks if SSL verification is disabled in global Git config
  - Run platform specific `envs/<platform>/setup.sh` if it exisits

### Enterprise Configuration (`config.include`):
- `core.fscache = true`: Enable file system cache on Windows (now it's default
  in the Git installer for Windows)
- `help.autocorrect = 1`: Automatically correct wrong typed commands after 0.1 sec.
- `color.diff = auto`: Only use color when output is to the terminal
- `color.status = auto`: Only use color when output is to the terminal
- `color.branch = auto`: Only use color when output is to the terminal
- `color.ui = true`: Only use color when output is to the terminal
- `submodule.fetchJobs = 0`: 0 = Reasonable default for how many submodules
  are fetched/cloned at the same time
- `pull.rebase = preserve`: When calling `git pull` always use rebase
  (preserving local merge commits) instead of merging  
  **=> to be checked if this is desired for all**
- `rebase.autostash = true`: Automatically creates a temp. stash before rebase
  and apply after rebase
- `push.default = simple`: Push the current branch to the upstream, but only
  if the remote branch name matches
- `lfs.batch = true`: Use the batch API instead of requesting objects individually
- `lfs.concurrenttransfers = 10`: 10 concurrent uploads/downloads
- `lfs.transfer.maxretries = 10`: 10 retries LFS will attempt per OID
- `filter.lfs.clean = git-lfs clean %f`: Git LFS called for git checkout
- `filter.lfs.smudge = git-lfs smudge %f`: Git LFS called for git add
- `filter.lfs.process = git-lfs filter-process`: Process all blobs with a single
  filter invocation
- `filter.lfs.requried = true`: If an error occurs for one file then interpret
  this as an error
- `url."/// ATTENTION ...".pushInsteadOf = "https://github.com"`: Push protection
- `url."/// ATTENTION ...".pushInsteadOf = "git@github.com"`: Push protection
- `url."/// ATTENTION ...".pushInsteadOf = "https://bitbucket.org"`: Push protection
- `url."/// ATTENTION ...".pushInsteadOf = "git@bitbucket.org"`: Push protection
- `url."/// ATTENTION ...".pushInsteadOf = "https://gitlab.com"`: Push protection
- `url."/// ATTENTION ...".pushInsteadOf = "git@gitlab.com"`: Push protection
- `alias.st = status`: Shortcut for git status
- `alias.br = branch`: Shortcut for git branch
- `alias.lol = "log --pretty=oneline --abbrev-commit --graph --decorate"`: Shortcut
  for showing history
- `alias.prlog = "log --pretty=oneline --abbrev-commit --graph --decorate --first-parent"`:
  Shortcut for showing only the first parent log
- `alias.adsk = "!f() {...}; f"`: Runs extension scripts passed as argument
- `ghfw.disableverification = true`: Ensure that GitHub for Windows client does
  not modify the git configuration file

Additionally (not yet in `config.include`):
- `core.autocrlf = false`: Ensure that line endings are not touched at all  
  **=> to be checked if this is desired for all**

### Git Add-On Scripts:
- `checkout.sh`: Adds submodule support
- `clean-checkout.sh`: Real clean checkout, adds submodule support
- `clone.sh`: Efficient cloning with Git LFS
- `copr.sh`: Checkout pull request (= already merged with base branch before published)
- `enable-public-push.sh`: Remove github.com push protection
- `help.sh`: Print all available commands
- `mkpr.sh`: Creates pull request
- `mkrepo.sh`: Create user repository on GitHub
- `paste.sh`: Paste code to GitHub's gist service
- `pull.sh`: Pulls with updating the submodules also
- `show-deleted.sh`: List files that have been deleted from branch
- `teardown.sh`: Remove credentials from credential store
- `version.sh`: Prints version number

## Supported Platforms
- Windows
- OSx
- Linux

## Use Cases
### Company adds company specific script
There shall be a way to store company specific scripts. These scripts shall be
included in help, ...

### Company patches generic script
There shall be a way to patch existing generic scripts for a company.

### Company deletes generic script
There shall be a way to delete generic scripts for a company, because they might
be dangerous or the use case is not covered in that company.

### Company updates generic scripts
When updating the generic scripts to a new version then the added, patched and
deleted scripts shall be kept. It is the repsonsiblity of the company to check
if the company adaptations are still valid.

### User specific scripts
If users write own scripts they should not be overwritten when an update is done.

### Different implementation languages
It shall be possible to implement commands in different languages:
- bash
- perl
- powershell (Windows only)
- batch (Windows only)

## Design Ideas

### Company specific folder
On top-level there shall be a new folder with the $KIT_ID name, e.g. adsk which
contains company specific scripts. When this folder only exists on a branch
`adsk-production` then a merge would never have a conflict, because this folder
only exists in that branch and not on the `master` branch.

Proposed directory structure:
```
lib             => generic scripts, so move all scripts here
lib/lnx         => generic linux specific scripts
lib/osx         => generic OSx specific scripts
lib/win         => generic windows specific scripts
lib/other       => generic other specific scripts
<company>       => company OS independent scripts
<company>/lnx   => company linux specific scripts
<company>/osx   => company osx specific scripts
<company>/win   => company windows specific scripts
<company>/other => company windows specific scripts
```

### Company Adaptations
#### Alternative A: List of allowed features in `enterprise.constants`
- In `enterprise.constants` for each command define which script shall be executed.
  - Added scripts: Set path to company folder
  - Patched scripts: Set path to company folder
  - Removed scripts: Don't define command
- In `config.include` the path of the corresponding command script shall be read
  from `enterprise.constants`.

#### Alternative B: setup.sh shall run a company specific setup.sh
In `setup.sh` at the end run `$KIT_ID/setup.sh` (if it exists) which contains
company specific setup, e.g. scripts to be added, patched, or removed:
- Added scripts: copy from a company folder to the main folder
- Patched scripts: copy and overwrite from a company folder to the main folder
- Removed scripts: delete from the main folder

#### Alternative C: Check for company specific script
- In `config.include` first check if `$KIT_ID/<command>.sh` exists
  To get this working the `config.include` must be changed:
  ```shell
   ...
   elif [ -e \"$KIT_PATH/<company>/$COMMAND.sh\" ]; then
      bash \"$KIT_PATH/<company>/$COMMAND.sh\" $@; \
  ...
  ```
  Open: How to get the `<company>`. Maybe extract this code into a shell script
  `runcmd.sh` which includes `enterprise.constants`
- If so then execute the company specific script
- If not then check if `<command>.sh` exists
- If so then execute the generic script
- Problem: how to remove a generic script

#### Alternative D: Always run company specific script
- In `config.include` always check if `$KIT_ID/<command>.sh` exists
- If so then execute the company specific script
- The company specific script might just execute the generic script or it might
  have company specific content
- With this alternative

## Configuration Data
### Git
- URL to get Git releases (or use network location?)
- Version to get
- Checksum
- Path to install Git

### Git LFS
- URL to get Git LFS releases (or use network location?)
- Version to get
- Checksum

### GitHub
- Server URL

### JIRA
- Server URL

### Enterprise Config
- Company Name
- Kit Name (= shortcut for company)
  Alternatively the kit could be company neutral, e.g.
  - `git ext <command>` or
  - `git addon <command>` or
  - `git custom <command>`
- Enterprise Config repository URL
  Alternative: get it via `git remote get-url origin`
- E-Mail address of company support

## Open Points
- Different script languages need the `enterpise.constants`:
  - __bash__: solved by `source` command
  - __perl__: needs a function to read and define as public variables
  - __powershell__: needs a function to read and define as public variables
  - __batch__ (if necessary): needs a function to read and define as public variables  
    (e.g. http://stackoverflow.com/questions/2866117/read-ini-from-windows-batch-file)
- Split `setup.sh` into smaller library functions.
  `setup.sh` might be nearly always company specific, but library functions could
  be helpful.
