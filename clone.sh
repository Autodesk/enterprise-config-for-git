#!/usr/bin/env bash
#
# Clone Git repositories and download Git LFS files in parallel.
# See more info here: https://github.com/github/git-lfs/issues/931
#
# Usage: git <KIT_ID> clone --<OPTION> <VALUE> [<TARGET DIRECTORY>]
#
set -e
NONGIT_OK=1
# Use git-sh-setup to initialize Git variables
. "$(git --exec-path)/git-sh-setup"

# Source shared kit content
KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

: ${GIT_TRACE:=1}
declare default_server=$GITHUB_SERVER

# Add user to URL, so that it never needs to be provided
declare user=$(git config --global adsk.github.account)
[[ $user ]] && default_server="$user@$default_server"

declare -a args
declare -i idx
declare ci_stream
declare ci_ibid
declare ci_upstream
declare exit_status
declare ci_transaction_id

args=("$@")
argument="$3"

# Functions start here

####################################################################
# usage - This function prints the usage with examples and exits
#         with exit status 0 or 1 depending on parameter.
#
# IN: None 
#
# OUT: Exits with error code 0
#
function usage(){
status "$2"
cat <<EOF
Usage: git emc clone --<OPTION> <VALUE> [<TARGET DIRECTORY>]
       -i| --ibid  : Provide the IBID number ex. git emc clone --ibid 226040
       -v| --revision : Provide the revision number ex. git emc clone --revision 4.5.0.1518789815
       -r| --remote : Provide the remote url ex. git emc clone --remote https://eos2git.cec.lab.emc.com/Rel-Eng/unity.git
                                                 git emc clone --remote unity-platform/unity
       -R| --rally  : Provide Rally Task ID or User Story number ex. git emc clone --rally TA19145
       -j| --jira  : Provide a valid JIRA ID ex. git emc clone --jira MDT-28547
       -a| --remedy : Provide a valid AR number ex. git emc clone --remedy AR950166
EOF
exit $1
}

####################################################################
# process_clone - This function clones a repository and creates a
#                 dev branch based on the input provided
#
# IN: Repository information
#     Branch 
#
# OUT: None 
#
function process_clone() {
    branch=$1
    branch_name="dev/$user/$branch"
    ci_stream=$(echo $ci_stream | sed 's/:/\//')
    IFS='/' read -r -a repo_details <<< "$ci_stream"
    IFS=':' read -r -a repo <<< "${repo_details[2]}"

    if [[ -z "$argument" ]]; then
        argument="${repo[0]}"
    fi

    if [[ ${repo_details[1]} =~ "PIE" ]]; then
        fork_repo=$(git config emc.domain.fork) || die "The domain fork is not set. Please set the domain fork by using the command and re-run the script: git config --global emc.domain.fork <Domain name>"
        status "Cloning https://${repo_details[0]}/$fork_repo/${repo[0]}.git"
        git-lfs clone --recursive "https://${repo_details[0]}/$fork_repo/${repo[0]}.git" $argument || die "Unable to clone https://${repo_details[0]}/$fork_repo/${repo[0]}.git"
    else
        status "Cloning https://${repo_details[0]}/${repo_details[1]}/${repo[0]}.git"
        git-lfs clone --recursive "https://${repo_details[0]}/${repo_details[1]}/${repo[0]}.git" $argument || die "Unable to clone https://${repo_details[0]}/${repo_details[1]}/${repo[0]}.git"
    fi

    if [[ -d $argument ]]; then
        cd $argument
        if [[ $jira || $remedy || $rally ]]; then
            if [[ ${repo[0]} == "unity" ]]; then
                status "Checking out the IBID : $ci_ibid"
                git emc checkout --ibid "$ci_ibid" --remote "https://${repo_details[0]}/${repo_details[1]}/${repo[0]}.git" || die "Unable to checkout IBID $ci_ibid"
                status "Creating development branch $branch_name"
                git checkout -b "$branch_name"  || die "Unable to checkout new branch $branch_name"
                git branch -u "$ci_upstream" || die "Unable to set upstream branch"
            else
                git checkout "$ci_transaction_id" || die "Unable to checkout to $ci_transaction_id"
            fi
        else
            if [[ ${repo[0]} == "unity" ]]; then
                status "Checking out the IBID id : $ci_ibid"
                git emc checkout --ibid "$ci_ibid" --remote "https://${repo_details[0]}/${repo_details[1]}/${repo[0]}.git"  || die "Unable to checkout IBID $ci_ibid"
            else
                git checkout "$ci_transaction_id" || die "Unable to checkout to $ci_transaction_id"
            fi
        fi
    else 
        die "The directory $argument does not exist"
    fi
}

####################################################################
# process_ibid_data - This function makes an API call to IBID and 
#                     fetches the content based on the search 
#                     criteria 
#
# IN: Search string - ibid_id/build_revision 
#     Search value - IBID/Version number
#
# OUT: None
#
function process_ibid_data() {
    query_string="{\"query\":\"$1 = '$2'\"}"

    # Redirecting the json output to a file
    status=$(curl -s -H "Accept: application/json" -H "Content-Type: application/json" -X PUT http://$IBID_SERVER/api/search -d "$query_string")
    #Fetch data from the JSON data
    ci_stream=$(jq -r '.results[].stream' <<< "$status")
    ci_stream=${ci_stream/https:\/\//}
    ci_upstream=${ci_stream##*:}
    ci_ibid=$(jq -r '.results[].ibid_id' <<< "$status" )
    ci_transaction_id=$(jq -r '.results[].transaction_id' <<< "$status")

    #validate if transation ID and stream data is not empty	 
    if [[ $ci_stream == "null" || -z $ci_stream  || $ci_ibid == "null" || -z $ci_ibid || $ci_upstream == "null" || -z $ci_upstream || $ci_transaction_id == "null" || -z $ci_transaction_id ]]; then
        die "Could not fetch the repo and branch details of the entered search criteria : $2"	
    fi
}

####################################################################
# process_rally - This function makes an API call to Rally and
#                 fetches the content for the US/Task. 
#
#**NOTE: This function is still under development and exits with 
#        an error message stating the same
#
# IN: US or Task number
#
# OUT: None
#
function process_rally() {
    #We need to get Feature information and name of the branch to clone, the field is not present in Rally, 
    die "Rally integration is under development. Exiting.."
    symbol=${rally:0:2}
    number=${rally:2}

    #Rally REST API url to fetch JSON output of entered task
    if [[ "$symbol" =~ TA|US ]]; then 
        #Rally REST API url to fetch JSON output
        url=$( [ "$symbol" == "TA" ] && echo  "$RALLY_URL/task?query=(FormattedId%20%3d%20$rally)&fetch=true" || echo  "$RALLY_URL/HierarchicalRequirement?query=(FormattedId%20%3d%20$rally)&fetch=true" )
    else
        die "Invalid rally ID"
    fi

    status=$(curl -s --header "zsessionid:$RALLY_API_KEY" -H "Content-Type: application/json" "$url" |  jq -r '.QueryResult.TotalResultCount')

    if [ $status == 1 ]; then
        status "$rally exists"
        #script to fetch version data from json output
    else
        die "$rally doesn't exists"
    fi
}

####################################################################
# process_jira - This function makes an API call to JIRA and
#                fetches the version information for the JIRA ID 
#                provided. This version number os processed to get
#                the repo, branch and transaction details
#
# IN: JIRA ID 
#
# OUT: None
#
function process_jira() {
    status "Querying for version information from Jira using the ticket, $jira"

    # **NOTE: The field name is customefield_11102 and there is no original name to it. So we are using it here. 
    version=$(curl -s -u $user -X GET -H "Content-Type: application/json" "$JIRA_URL/$jira" | jq -r '.fields.customfield_11102')
    if [ -z $version ]; then
        die "Version was not found for the Jira ticket. Exiting...!"
    else
        status "The version information for the issue, $jira is $version"
    fi
    status "Searching for git commit id using the version, $version"
    if [[ $version =~ ^[0-9]\.[0-9]\.[0-9]\.[0-9]+$ ]]; then
        process_ibid_data "build_revision" "$version"
        process_clone "${jira}"
    else
       die "The version information fetched does not comply with the standard version format <xx.xx.xxxx>  Exiting...!"
    fi
}

####################################################################
# process_remedy - This function makes an API call to Remedy and
#                  fetches the version information for the AR ID
#                  provided. This version number os processed to get
#                  the repo, branch and transaction details
#
# IN: AR
#
# OUT: None
#
function process_remedy() {
    status "Querying for version information from Remedy using the ticket, $remedy"
    # Read the user password
    echo -n "Enter password for user $user:"
    read -s password
    remedy=${remedy:2:${#remedy}} 
    version=$(curl -s -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$REMEDY_URL?Entry-Id=$remedy&user=$user&pass=$password&Version%20Found=0")

    # Unsetting the password field.
    unset password

    if [[ $version =~ ^ERROR ]]; then
        die "AR validation failed with \"$version\". Exiting...!"
    else
        #Format version
        version=${version/[[:space:]]*\:/}
        status "The version information for the issue, $remedy is $version"
    fi
    status "Searching for git commit id using the version, $version"

    if [[ $version =~ ^[0-9]\.[0-9]\.[0-9]\.[0-9]+$ ]]; then
        process_ibid_data "build_revision" $version
        process_clone "AR$remedy"
    else
        die "The version information fetched does not comply with the standard version format.\n Please try using git emc clone --revision <xx.xx.xx.xxxx>"
    fi
}

### Main script starts here

# Check if the below programs are installed
command -v jq >/dev/null 2>&1 || die  "This script requires jq installed. Please install jq and try again. Exiting..."
command -v curl >/dev/null 2>&1 || die "This script requires curl installed. Please install curl and try again. Exiting..."

# Validate user info
[[ $user ]] || die "User name is not set. Please execute /usr/local/bin/git-emc-install -u <corp_id> -e <email> to set username" 

# Process arguments
params=$(getopt -o "i:v:r:R:j:a:h" -l "help,ibid:,revision:,remote:,rally:,jira:,remedy:" -n "$0" -- "$@") || usage 1 "Invalid parameters"

if [ $? != 0 ] || [ $# -gt 3 ]; then
    usage 1 "Invalid number of parameters...Printing usage for your reference"
fi
eval set -- "$params"

case $1 in
    -i|--ibid)
       ibid=$2
       shift
       ;;
    -v|--revision)
       revision=$2
       shift
       ;;
    -r|--remote)
       remote=$2
       shift
       ;;
    -R|--rally)
       rally=$2
       shift
       ;;
    -j|--jira)
       jira=$2
       shift
       ;;
    -a|--remedy)
       remedy=$2
       shift
       ;;
    -h|--help)
       usage 0 "Printing usage for your reference"
       ;;
    *) usage 1 "User input is incorrect...Printing usage for your reference"
       ;;
esac

# Function calls to process the IBID/Revision/Rally/JIRA details
if [[ $ibid ]]; then
    if [[ $ibid =~ ^[0-9]+$ ]]; then
        process_ibid_data "ibid_id" "$ibid"
        process_clone "IBID$ibid"
    else 
        usage 1 "User input is incorrect...Printing usage for your reference"
    fi
elif [[ $revision ]]; then
    if [[ $revision =~ ^[0-9]\.[0-9]\.[0-9]\.[0-9]+$ ]]; then
        process_ibid_data "build_revision" $revision
        process_clone  "$revision"
    else
        usage 1 "User input is incorrect...Printing usage for your reference" 
    fi
elif [[ $remote ]]; then
    if [[ "$remote" = */* && "$remote" != http* && "$remote" != git@* ]]; then
        args=("https://${default_server}/${args[1]}" "${args[@]:2}")
        git-lfs clone --recursive "${args[@]}" || die "Unable to clone $args"
    else
        git-lfs clone --recursive $remote $argument || die "Unable to clone $remote"
    fi
elif [[ $rally ]]; then
    if [[ $rally =~ ^[A-Z]{2}[0-9]+$ ]]; then
        process_rally
    else
        usage 1 "User input is incorrect...Printing usage for your reference"
    fi
elif [[ $jira ]]; then
    if [[ $jira =~ ^MDT-[0-9]+$ ]]; then
        process_jira
    else
        usage 1 "User input is incorrect...Printing usage for your reference"
    fi
elif [[ $remedy ]]; then
    if [[ $remedy =~ ^AR[0-9]+$ ]]; then
        process_remedy
    else
        usage 1 "User input is incorrect...Printing usage for your reference"
    fi
fi

