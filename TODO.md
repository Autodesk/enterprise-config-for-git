# TODO for configurable-company

- [ ] `checkout.sh`: Necessary only if using submodules
- [ ] `clean-checkout.sh`: Could be optimized if not using submodules
- [ ] `clone.sh`: Necessary only if using Git LFS
- [ ] `copr.sh`: Necessary only if using GitHub Enterprise
- [ ] `enable-public-push.sh`: Necessary only if working additionally with github.com
- [ ] `help.sh`: Help should be generated out of single commands.  
  Maybe some commands will be skipped for a certain company
- [ ] `install-helper.ps1`: to be analyzed
- [ ] `install.bat`: to be analyzed
- [ ] `install.sh`: to be analyzed
- [ ] `mkpr.sh`: Necessary only if using GitHub Enterprise
  - [x] Variables needs to be renamed (`GITHUB_*` => `GHE_*`)
  - [x] `adsk` needs to be replaced with `$KIT_ID`
  - [ ] slug specific code must be isolated
- [ ] `mkrepo.sh`: Necessary only if using GitHub Enterprise
  - [x] Variables needs to be renamed (`GITHUB_*` => `GHE_*`)
- [ ] `paste.sh`: Necessary only if using GitHub Enterprise
  - [x] Variables needs to be renamed (`GITHUB_*` => `GHE_*`)
- [ ] `pull.sh`: Necessary only if using submodules
- [ ] `setup.sh`: Split different tasks into separate scripts for better tailoring
- [x] `show-deleted.sh`: OK
- [ ] `teardown.sh`: Contains string << YOUR GITHUB SERVER >>. Should be replaced with
  `$GHE_SERVER`
- [x] `version.sh`: OK

## Features
- Submodules
- Git LFS
- GitHub Enterprise

## Platforms
- Windows
- Mac OSx
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

### Company adds company specific script
Put the script in `<company>` folder.
To get this working the `config.include` must be changed:
```shell
   ...
   elif [ -e \"$KIT_PATH/<company>/$COMMAND.sh\" ]; then
      bash \"$KIT_PATH/$COMMAND.sh\" $@; \
  ...
```
### Company Adaptations
#### Alternative A: disallow features in `enterprise.constants`
- Some features (= scripts) might be dangerous
- Based on values in `enterprise.constants` features (= scripts) shall be enabled
  / disabled.
- Therefore each script must check if the feature is allowed to avoid direct calls
- In `config.include` there should be a check if the featrue is allowed before
  calling it

#### Alternative B: setup.sh shall run a company specific setup.sh
In `setup.sh` at the end run `$KIT_ID/setup.sh` (if it exists) which contains
company specific setup, e.g. scripts to be added, patched, or removed:
- Added scripts: copy from a company folder to the main folder
- Patched scripts: copy and overwrite from a company folder to the main folder
- Removed scripts: delete from the main folder
