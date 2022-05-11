# Enterprise Config for Git

A painless Git setup with an easy way to share Git configs and scripts within a company using GitHub Enterprise or any similar on-premise Git hosting service.

_Enterprise Config for Git_ adds a new Git setup command (e.g. `git mycompany`) to your Git config (via Git config alias) that configures a developer machine. The setup command checks the installed Git version, ensures Git LFS is installed properly, configures the user name and email based on the GitHub Enterprise profile, and configures the Git credential helper with a GitHub Enterprise token. It also adds an easy way to distribute company Git configs (e.g. [Git push protection](./config.include#L25-L39)) and Git helper scripts (e.g. [`git emc clone`](./clone.sh)).

_Enterprise Config for Git_ supports Windows, Mac and Linux and a great number of shells such as BASH, ZSH, DASH, cmd.exe, and PowerShell.

Please find more details about _Enterprise Config for Git_ in the corresponding Git Merge 2016 talk ([slides](https://speakerdeck.com/larsxschneider/git-at-scale)).

## Getting Started

In order to use _Enterprise Config for Git_ you need to fork it to your GitHub Enterprise instance (ensure that every engineer has read access) and adjust it for your company:
* Define the [name of the setup command](./config.include#L51) for your company
* Define your _Enterprise Config for Git_ [constants](./enterprise.constants)
* Configure your desired [company email pattern](./lib/setup_helpers.sh#L84).
* Create a production branch based on the master branch.


## Install Enterprise Config

* git clone --branch integration https://eos2git.cec.lab.emc.com/DevEnablement/enterprise-config-for-git.git  ~/.enterprise
* git config --global include.path ~/.enterprise/config.include
* ~/.enterprise/setEmail.sh $NTID $EMAIL
* git emc

## Extend Enterprise Config

Any Git config you define in `config.include` will be distributed to all your engineers with the setup command. Plus you can add shell scripts to the root directory of _Enterprise Config for Git_ that are available to all engineers via the setup command (see the [`clone.sh`](./clone.sh) implementation as example for `git emc clone`)

## Need Help?

_Enterprise Config for Git_ is a fairly new project and not very mature at this point. In case of trouble or questions please create a GitHub issue and we will try to get back to you ASAP.

## License
[Apache License 2.0](./LICENSE)
