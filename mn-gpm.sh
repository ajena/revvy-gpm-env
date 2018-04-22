export git_topdir=""
export HISTTIMEFORMAT="%d/%m/%y %T "
export LC_ALL="en_US.UTF-8"

export SF_BUILD_ROOT="/d/Users/Abhilash/dev/github/revvy-gpm/InternationalReferencePricing"
export PATH=$SF_BUILD_ROOT/build/ui/node_modules/grunt-cli/bin:$PATH

alias sf-git="cd /d/Users/Abhilash/dev/github/revvy-gpm"
alias heroku-git="cd /d/Users/Abhilash/dev/github/revvy-gpm-heroku"
alias ws-eclipse="cd /d/Users/Abhilash/dev/workspace/eclipse/"

alias master="git checkout master"

alias meld="/D/Users/Abhilash/dev/tools/diff/Meld/Meld.exe"

function logs_heroku() {
    appname="$1"
	if [ "$appname" == "" ]
        then appname="dev10-gpm"
    fi
    echo
    echo "heroku logs -t -a $appname"
	echo
	heroku logs -t -a $appname
}

function gitlog() {
    n=10
    if [ "$#" != 0 ]
        then n=$1
    fi

    echo
    git status
    echo
    
    git log -"$n" --date=local --pretty="%C(auto)%h (%<(20,trunc)%aN %cd) %<(100,trunc)%s" $2
}

function gitamend() {
   echo
   echo "git commit -a --amend -no-edit"
   echo
   git commit -a --amend --no-edit
}

function git_ignore() {
    filepath="$1"
    if [ "$filepath" == "" ]
	    then
		echo
        echo "USAGE: git_ignore <file_path>"
        return
    fi

	echo
    echo "git update-index --assume-unchanged $filepath"
    
    git update-index --assume-unchanged $filepath
}

function rebase() {
    curr_branch=$(git branch | grep "*" | sed 's/\*//g' | xargs)
    echo
    echo "git fetch --prune"
    echo
	git fetch --prune
	echo
	echo "git checkout ."
	git checkout .
	echo
    echo "git pull --rebase origin $curr_branch"
    echo
    git pull --rebase origin $curr_branch
	echo
}

function push() {
    curr_branch=$(git branch | grep "*" | sed 's/\*//g' | xargs)
    echo
    echo "git push origin $curr_branch $*"
    echo
	git push origin $curr_branch $*
}

function pushlocal() {
    git add src
    git commit -m "Org Syncup @ $(date '+%d%b%y %k%M')"
    git push
}

function pushheroku() {
    heroku_app=$1
	if [ "$heroku_app" == "" ]
	    then
        heroku_app="heroku"
    fi
    curr_branch=$(git branch | grep "*" | sed 's/\*//g' | xargs)
    echo
	echo "git push -f $heroku_app $curr_branch:master"
	echo
    git push -f $heroku_app $curr_branch:master
}

function set_git_topdir() {
    git_topdir=$(git rev-parse --show-toplevel)
	if [[ $git_topdir ==  fatal* ]] ;
	    then
	    echo $git_topdir
		echo "Execute the command from a valid git repository."
		exit 0
	fi
}

# USAGE(for UI code deployment) : deploy aj_sf2 UIResource/**/*
function deploy() {
    eval "invokeAntTask deployMnForce $*"
}

function deployAndTest() {
    eval "invokeAntTask deployAndTestMnForce $*"
}

function clean() {
    eval "invokeAntTask cleanMnForce $*"
}

function delete() {
    eval "invokeAntTask deleteAll $*"
}

function import() {
    eval "invokeAntTask importAll $*"
}

function prepareUI() {
    eval "invokeAntTask prepareUI $*"
}

function invokeAntTask() {
    # Check for required number of arguments
    if [ "$#" -lt 2 ]
        then 
        echo
        echo "USAGE: invokeAntTask [cleanMnForce|deployMnForce|deployAndTestMnForce|importAll|deleteAll] <sf.propfile_name>"
        echo "E.g., invokeAntTask deployMnForce aj_sf"
        return
    fi
    
    # Check for valid ant target
    if [ "$1" != "cleanMnForce" ] && [ "$1" != "deployMnForce" ] && [ "$1" != "deployAndTestMnForce" ] && [ "$1" != "importAll" ] && [ "$1" != "deleteAll" ] && [ "$1" != "prepareUI" ]
        then 
        echo
        echo "Invalid ant target '$1'"
        echo "USAGE: invokeAntTask [cleanMnForce|deployMnForce|deployAndTestMnForce|importAll|deleteAll|prepareUI] <sf.propfile_name>"
        echo "E.g., invokeAntTask deployMnForce aj_sf"
        return
    fi

    # Evaluate git toplevel directory
	git_topdir=$(git rev-parse --show-toplevel)
	if [[ $git_topdir == "" ]] ;
	    then
		echo "Execute the command from a valid git repository."
		return
	fi
	
	# Cache pwd
	cached_pwd=$(pwd)

    # Now change the directory to the one that contains the build.xml file
    eval "cd $git_topdir/InternationalReferencePricing/build/bin"

    # Invoke the ant target
    if [ $# -eq 2 ]
        then
        echo
        echo "ant -Dsf.propfile=$2 $1"
        echo
        eval "ant -Dsf.propfile=$2 $1"
    else
        echo
        echo "ant -Dsf.propfile=$2 -Dsf.files=$3 $1"
        echo
        eval "ant -Dsf.propfile=$2 -Dsf.files=$3 $1"
    fi
	
	# Change the directory to the cached pwd
	eval "cd $cached_pwd"
}

function heroku_start() {
    echo "heroku ps:scale web=1 -a dev10-gpm"
    heroku ps:scale web=1 -a dev10-gpm
}

function heroku_stop() {
    echo "heroku ps:scale web=0 -a dev10-gpm"
    heroku ps:scale web=0 -a dev10-gpm
}
