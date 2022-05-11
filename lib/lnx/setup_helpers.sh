function open_url () {
    :
}

function credential_helper {
    echo cache
}

function credential_helper_parameters {
    # Cache credentials for 24h
    echo "--timeout=86400"
}

function git_lfs_error_exit {		
  read -r -d '\0' MESSAGE <<EOM
Git LFS is not installed on your Dev VM.
Please run c4dev_update.\0
EOM
  error_exit "$MESSAGE"		
}

function install_git_lfs {
    check_git_lfs no-install
}
