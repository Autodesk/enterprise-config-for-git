# Enterprise Config for Git

A painless Git setup with an easy way to share Git configs and scripts within a company using GitHub Enterprise.

_Enterprise Config for Git_ adds a new Git setup command (e.g. `git mycompany`) to your Git config (via Git config alias) that configures a developer machine. The setup command checks the installed Git version, ensures Git LFS is installed properly, configures the user name and email based on the GitHub Enterprise profile, and configures the Git credential helper with a GitHub Enterprise token. It also adds an easy way to distribute company Git configs (e.g. [Git push protection](./config.include#L25-L35)) and Git helper scripts (e.g. [`git adsk clone`](./clone.sh)).

_Enterprise Config for Git_ supports Windows, Mac and Linux and a great number of shells such as BASH, ZSH, DASH, cmd.exe, and PowerShell.

Please find more details about _Enterprise Config for Git_ in the corresponding Git Merge 2016 talk ([slides](https://speakerdeck.com/larsxschneider/git-at-scale)).


## Getting Started

In order to use _Enterprise Config for Git_ you need to fork it to your GitHub Enterprise instance and adjust it for your company:
* Define the [name of the setup command](./config.include#L46) for your company
* Set the [GitHub Enterprise server](./setup.sh#L8) (e.g. `github.mycompany.com`)
* Set _Enterprise Config for Git_ [organization/repository of your fork](./setup.sh#L9) on your GitHub Enterprise server (e.g. `tools/enterprise-config`). Please ensure every engineer has read access.
* Define your [contact in case of errors](./setup.sh#L16)
* Register an [OAuth application](https://developer.github.com/v3/oauth/) on your GitHub Enterprise server and setup the _Enterprise Config for Git_ [client ID and secret](./setup.sh#L12-L13).
* Configure your desired [company email pattern](./lib/setup_helpers.sh#L84).
* Create a production branch based on the master branch.


## Install Enterprise Config

```
git clone --branch production <<YOUR ENTERPRISE CONFIG URL>> ~/.enterprise
git config --global include.path ~/.enterprise/config.include
git <<YOUR SETUP COMMAND>>
```


## Extend Enterprise Config

Any Git config you define in `config.include` will be distributed to all your engineers with the setup command. Plus you can add shell scripts to the root directory of _Enterprise Config for Git_ that are available to all engineers via the setup command (see the [`clone.sh`](./clone.sh) implementation as example for `git adsk clone`)


## Need Help?

_Enterprise Config for Git_ is a fairly new project and not very mature at this point. In case of trouble or questions please create a GitHub issue and we will try to get back to you ASAP.

## License
[Apache License 2.0](./LICENSE)
